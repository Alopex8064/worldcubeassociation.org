<?php
#----------------------------------------------------------------------
#   Initialization and page contents.
#----------------------------------------------------------------------

$currentSection = 'admin';
require( '../includes/_header.php' );

analyzeChoices();
saveChoices();
offerChoices();

require( '../includes/_footer.php' );

#----------------------------------------------------------------------
function analyzeChoices () {
#----------------------------------------------------------------------
  global $chosenId, $chosenConfirm, $chosenName, $chosenNameHtml, $chosenCountryId, $chosenGender, $chosenDay, $chosenMonth, $chosenYear, $chosenUpdate, $chosenFix;

  $chosenConfirm     = getBooleanParam( 'confirm'   );
  $chosenUpdate      = getBooleanParam( 'update'    );
  $chosenFix         = getBooleanParam( 'fix'       );
  $chosenId          = getNormalParam ( 'id'        );
  // Gah, this is awful. We can't call getNormalParam because it refuses to
  // return anything if the parameter has a quote in it. We don't want to call
  // getMysqlParam, as we're using pdo_query throughout this file, and we don't
  // want double escaping to occur.
  $chosenName        = getRawParamThisShouldBeAnException( 'name' );
  $chosenNameHtml    = getHtmlParam   ( 'name'      );
  $chosenCountryId   = getNormalParam ( 'countryId' );
  $chosenGender      = getNormalParam ( 'gender'    );
  $chosenDay         = getNormalParam ( 'day'       );
  $chosenMonth       = getNormalParam ( 'month'     );
  $chosenYear        = getNormalParam ( 'year'      );

}

#----------------------------------------------------------------------
function saveChoices () {
#----------------------------------------------------------------------
  global $chosenId, $chosenConfirm, $chosenName, $chosenNameHtml, $chosenCountryId, $chosenGender, $chosenDay, $chosenMonth, $chosenYear, $chosenUpdate, $chosenFix;

  if( $chosenFix ){

    #--- Change the Results table if the name has been changed.
    $persons = pdo_query(
      "SELECT * FROM Persons WHERE id=? AND subId=1",
      array($chosenId)
    );
    if( count( $persons ) == 0 ){
      noticeBox(false, 'Unknown WCA Id '.$chosenId);
      return;
    }
    $person = array_shift( $persons );
    $recordsMayHaveChanged = false;

    // do not allow country to be 'fixed' (affects records).
    $oldCountryId = $person['countryId'];
    if($oldCountryId != $chosenCountryId) {
      $hasBeenACitizenOfThisCountryAlready = count( pdo_query( "SELECT * FROM Persons WHERE id=? AND countryId=?", array($chosenId, $chosenCountryId) ) ) > 0;
      if( $hasBeenACitizenOfThisCountryAlready ) {
        // If someone represented country A, and now represents country B, it's
        // easy to tell which solves are which (results have a countryId).
        // Fixing their country (B) to a new country C is easy to undo, just change
        // all Bs to As. However, if someone accidentally fixes their country from B
        // to A, then we cannot go back, as all their results are now for
        // country A.
        noticeBox(false, "Cannot change the country of someone to a country they have already represented in the past.");
        return;
      } else {
        pdo_query(
          'UPDATE Results SET countryId=? WHERE personId=? AND countryId=?',
          array($chosenCountryId, $chosenId, $oldCountryId)
        );
        $recordsMayHaveChanged = true;
      }
    }

    $oldPersonName = $person['name'];
    if( $oldPersonName != $chosenName ) {
      pdo_query(
        "UPDATE Results SET personName=? WHERE personId=? AND personName=?",
        array($chosenName, $chosenId, $oldPersonName)
      );
    }

    #--- Change the Persons table
    echo "changing name to $chosenName";//<<<
    pdo_query(
      "UPDATE Persons SET name=?, countryId=?, gender=?, year=?, month=?, day=? WHERE id=? AND subId='1'",
      array($chosenName, $chosenCountryId, $chosenGender, $chosenYear, $chosenMonth, $chosenDay, $chosenId)
    );

    $msg = "Successfully fixed $chosenNameHtml($chosenId).";
    if( $recordsMayHaveChanged ) {
      $msg .= " The change you made may have affected records, be sure to run <a href='/results/admin/check_regional_record_markers.php'>check_regional_record_markers</a>.";
    }
    noticeBox( true, $msg );

  }

  if( $chosenUpdate ){

    $persons = pdo_query(
      "SELECT * FROM Persons WHERE id=? AND subId=1",
      array($chosenId)
    );
    if( count( $persons ) == 0 ){
      noticeBox(false, 'Unknown WCA Id '.$chosenId);
      return;
    }

    $person = array_shift( $persons );

    if(( $person['name'] == $chosenName ) and ( $person['countryId'] == $chosenCountryId )){
      noticeBox(false, 'The name or the country must be different.');
      return;
    }

    dbCommand( "UPDATE Persons SET subId=subId+1 WHERE id='$chosenId'" );
    dbCommand( "INSERT INTO Persons(id, subId, name, countryId, gender, year, month, day) VALUES( '$chosenId', '1', '$chosenName', '$chosenCountryId', '$chosenGender', '$chosenYear', '$chosenMonth', '$chosenDay')" );

    noticeBox( true, "Successfully updated $chosenNameHtml($chosenId).");
  }

  $users = pdo_query(
    "SELECT * FROM users WHERE wca_id=?",
    array($person['id'])
  );
  if(count($users) > 0) {
    $user = array_shift( $users );
    noticeBox( true, "Don't forget to re-save the user <a href='/users/${user['id']}/edit'>here</a>! (simply clicking save on that page will copy over the data from the Persons table to the users table)" );
  }
}

#----------------------------------------------------------------------
function offerChoices () {
#----------------------------------------------------------------------
  global $chosenId, $chosenConfirm;

  adminHeadline( 'Change Person' );

  echo "<p style='width:45em'>Choose 'Fix' if you want to replace a person's information in the database. It will modify the Persons table accordingly and the Results table if the person's name is different. This should be used to fix mistakes in the database.</p>\n";

  echo "<p style='width:45em'>Choose 'Update' if the person's name or country has been changed. It will add a new entry in the Persons table and make it the current information for that person (subId=1) but it will not modify the Results table so previous results keep the old name.</p>\n";

  echo "<hr />";

  echo "<form method='POST'>\n";
  echo "<table class='prereg'>\n";
  textField( 'id', 'WCA Id', $chosenId, 11 );

  if( ! $chosenConfirm ) {
    echo "<tr><td>&nbsp;</td><td style='text-align:center'>";
    echo "<input type='submit' id='confirm' name='confirm' value='Confirm' style='background-color:#9F3;font-weight:bold' /> ";
    echo "</td></tr></table></form>";
    return;
  }

  $persons = pdo_query(
    "SELECT * FROM Persons WHERE id=? AND subId=1",
    array($chosenId)
  );
  if( count( $persons ) == 0 ){
    noticeBox(false, 'Unknown WCA Id '.$chosenId);
    return;
  }

  $person = array_shift( $persons );
  extract( $person );

  #--- Name
  textField( 'name', 'Name', $name, 50 );

  #--- Country
  $countries = pdo_query( "SELECT * FROM Countries" );
  $fieldC = '';
  foreach( $countries as $country ){
    $cId   = $country['id'  ];
    $cName = $country['name'];
    if( $cId == $countryId )
      $fieldC .= "  <option value=\"$cId\" selected='selected' >$cName</option>\n";
    else
      $fieldC .= "  <option value=\"$cId\">$cName</option>\n";
  }
  echo "  <tr><td width='30%'><label for='countryId'><b>Country</b></label></td>\n";
  echo "      <td><select id='countryId' name='countryId'>\n";
  echo $fieldC;
  echo "      </select></td></tr>\n";

  #--- Gender
  if( $gender == 'm' )
    $fieldG = "Male : <input type='radio' id='gender' name='gender' value='m' checked='checked' /> Female : <input type='radio' id='gender' name='gender' value='f' />";
  else if( $gender == 'f' )
    $fieldG = "Male : <input type='radio' id='gender' name='gender' value='m' /> Female : <input type='radio' id='gender' name='gender' value='f' checked='checked' />";
  else
    $fieldG = "Male : <input type='radio' id='gender' name='gender' value='m' /> Female : <input type='radio' id='gender' name='gender' value='f' />";
  echo "  <tr><td width='30%'><label for='gender'><b>Gender</b></label></td><td>$fieldG</td></tr>\n";

  #--- DoB
  echo "  <tr><td><b>Date of birth</b></td><td>";
  echo numberSelect( "day", "Day", 1, 31, $day );
  echo numberSelect( "month", "Month", 1, 12, $month );
  echo numberSelect( "year", "Year", date("Y"), date("Y")-100, $year );
  echo "</td></tr>\n";  

  #--- Submit
  echo "<tr><td>&nbsp;</td><td style='text-align:center'>";
  echo "<input type='submit' id='update' name='update' value='Update' style='background-color:#9F3;font-weight:bold' /> ";
?>
  <script>
    (function() {
      $('#update').click(function(e) {
        if(!confirm("Are you sure that you want to \"update\", not \"fix\", the competitor's data? (see information above)")) {
          e.preventDefault();
        }
      });
    })();
  </script>
<?php
  echo "<input type='submit' id='fix' name='fix' value='Fix' style='background-color:#9F3;font-weight:bold' /> ";
  echo "</td></tr></table></form>";

}

#----------------------------------------------------------------------
function textField ( $id, $label, $default, $size ) {
#----------------------------------------------------------------------
  $default = htmlspecialchars($default);
  echo "  <tr><td width='30%'><label for='$id'><b>$label</b></label></td><td><input id='$id' name='$id' type='text' value=\"$default\" size='$size' /></td></tr>\n";
}
