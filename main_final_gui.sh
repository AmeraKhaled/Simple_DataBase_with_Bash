#!/bin/bash
function createDatabase {
    dName=$(kdialog --inputbox "Enter name of database")
    mkdir "$dName"
    chmod +rwx "$dName"
    kdialog --msgbox "Database $dName Created Successfully"
    mainMenu
}

function connectDatabase {
    dbName=$(kdialog --inputbox "Enter Name of Database")
    if [ -d "$dbName" ]; then
        cd "$dbName" && kdialog --msgbox "Connected to $dbName." || kdialog --msgbox "Failed to Connect $dbName"
    else
        kdialog --msgbox "Not Found"
        mainMenu
    fi
    databaseMenu
}

function dropDatabase {
    DBname=$(kdialog --inputbox "Enter Database Name")
    if [ -d "$DBname" ]; then
        if kdialog --yesno "Are you sure you want to delete '$DBname'?" ; then
            rm -r "$DBname" && kdialog --msgbox "Database $DBname Removed Successfully." || kdialog --msgbox "Failed to remove database."
        else
            kdialog --msgbox "Deletion canceled."
        fi
    else
        kdialog --msgbox "Not Found"
    fi
    mainMenu
}

function createTable {
    Tname=$(kdialog --inputbox "Enter table name:")
    touch "$Tname"
    chmod +wrx "$Tname"
    kdialog --msgbox "Table \"$Tname\" created successfully."

    # Nested function to read unique column names
    function readUniqueColumnNames {
        tempColumns_str=$(kdialog --inputbox "Please enter column names (separated by space):")
        # Split the input string into an array
        read -r -a tempColumns <<< "$tempColumns_str"
        declare -A seen
        for col in "${tempColumns[@]}"; do
            if [[ -n "${seen[$col]}" ]]; then
                kdialog --msgbox "Error: Duplicate column name '$col' found. Please enter unique column names."
                return 1
            else
                seen[$col]=1
            fi
        done
        columnNames=("${tempColumns[@]}")
        return 0
    }
    while true; do
        if readUniqueColumnNames; then
            break
        fi
    done

    colDefs=()
    for name in "${columnNames[@]}"; do
        datatype_choice=$(kdialog --menu "Select datatype for column \"$name\":" \
            "1" "number" \
            "2" "string" \
            "3" "Date" \
            "4" "Boolean")
        case $datatype_choice in
            1) datatype="number" ;;
            2) datatype="string" ;;
            3) datatype="date" ;;
            4) datatype="boolean" ;;
            *) kdialog --msgbox "Invalid datatype selection. Please try again." ; continue ;;
        esac
        colDefs+=("$name|$datatype")
    done

    while true; do
        pkey=$(kdialog --inputbox "Which column should be the Primary Key? (${columnNames[*]})")
        found="false"
        for col in "${columnNames[@]}"; do
            if [[ "$col" == "$pkey" ]]; then
                found="true"
                break
            fi
        done
        if [[ "$found" == "true" ]]; then
            break
        else
            kdialog --msgbox "No column with that name found. Please try again."
        fi
    done

    pkDef=""
    newDefs=()
    for def in "${colDefs[@]}"; do
        IFS='|' read -r colName type <<< "$def"
        if [[ "$colName" == "$pkey" ]]; then
            pkDef="${colName}*|${type}"
        else
            newDefs+=("$def")
        fi
    done
    finalText="$pkDef"
    for def in "${newDefs[@]}"; do
        finalText="$finalText:$def"
    done

    echo "$finalText" > "$Tname"
    msg=$(echo -e "\nTable \"$Tname\" created successfully with the following structure:\n\n$(echo "$finalText" | tr ':' '\n' | awk -F '|' '{printf "%-15s | %s\n", $1, $2}')")
    kdialog --msgbox "$msg"
    databaseMenu
}

function dropTable {
    TName=$(kdialog --inputbox "Enter Table Name to be dropped:")
    if [[ -f "$TName" ]]; then
        if kdialog --yesno "Are you sure you want to delete '$TName'?" ; then
            rm "$TName"
            kdialog --msgbox "Table '$TName' deleted successfully."
        else
            kdialog --msgbox "Deletion canceled."
        fi
    else
        kdialog --msgbox "Table $TName does not exist."
    fi
    databaseMenu
}
function insertTable {
    # Show available tables and ask user to choose one
    tables=$(ls)
    kdialog --msgbox "Choose the table you want to insert into from:\n$tables"
    Tname=$(kdialog --inputbox "Enter the table name:")
    my_flag=true
    if [[ -f "$Tname" ]]; then
        line=$(head -n 1 "$Tname")
        data_types=($(echo "$line" | awk -F'[:|]' '{for (i=2; i<=NF; i+=2) print $i}'))
        column_names=($(echo "$line" | awk -F'[:|]' '{for (i=1; i<=NF; i+=2) print $i}'))
        kdialog --msgbox "Write the values you want to insert for the following columns:\n${column_names[*]}"
        values_str=$(kdialog --inputbox "Enter values separated by space (if you don't want to add write none):")
        # Convert the space‐separated string into an array
        values=($values_str)

        if [[ ${#values[@]} != ${#data_types[@]} ]]; then
            kdialog --msgbox "Error: The number of entered values does not match the number of columns."
            insertTable
            return
        fi

        for i in "${!values[@]}"; do
            value="${values[$i]}"
            expected_type="${data_types[$i]}"
            case $expected_type in
                "number")
                    if [[ ! $value =~ ^[+-]?[0-9]+$ ]]; then
                        kdialog --msgbox "Error: '$value' is not a valid number."
                        my_flag=false
                        break
                    fi
                    ;;
                "date")
                    if [[ ! $value =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "$value" >/dev/null 2>&1; then
                        kdialog --msgbox "Error: '$value' is not a valid date (expected format: YYYY-MM-DD)."
                        my_flag=false
                        break
                    fi
                    ;;
                "boolean")
                    if [[ ! $value =~ ^(true|false)$ ]]; then
                        kdialog --msgbox "Error: '$value' is not a valid boolean (expected: true or false)."
                        my_flag=false
                        break
                    fi
                    ;;
                "string")
                    # No validation needed for strings
                    ;;
                *)
                    kdialog --msgbox "Error: Unknown data type '$expected_type'."
                    my_flag=false
                    break
                    ;;
            esac
        done

        pk_flag=false
        first_value="${values[0]}"
        if grep -q "^$first_value|" "$Tname" ; then
            kdialog --msgbox "Error: The Primary key value '$first_value' is already present in the file!"
            pk_flag=false
        else
            pk_flag=true
        fi

        if [[ $my_flag == true && $pk_flag == true ]]; then
            formatted_data=$(IFS="|"; echo "${values[*]}")
            echo "$formatted_data" >> "$Tname"
            kdialog --msgbox "Data successfully added to $Tname."
        else
            kdialog --msgbox "You entered wrong data types."
        fi
    else
        kdialog --msgbox "There is no such table."
    fi
    databaseMenu
}

function selectTable {
    tableName=$(kdialog --inputbox "Enter the file (table) you want to select from:")
    if [[ -f "$tableName" ]]; then
        Rnumber=$(kdialog --inputbox "Enter the value you want to select (or '*' for all):")
        if [[ "$Rnumber" == "*" ]]; then
            result=$(tail -n +2 "$tableName")
            kdialog --msgbox "Selected rows:\n$result"
            databaseMenu
            return
        else
            matching_row=$(awk -F'|' -v id="$Rnumber" '$1 == id { print $0 }' "$tableName")
        fi

        if [[ -n "$matching_row" ]]; then
            kdialog --msgbox "Selected row:\n$matching_row"
        else
            kdialog --msgbox "Not found!"
        fi
    else
        kdialog --msgbox "Table Not Found"
    fi
    databaseMenu
}

function deleteFromTable {
    file=$(kdialog --inputbox "Enter the table name you want to delete from:")
    if [[ -f "$file" ]]; then
        rowNumber=$(kdialog --inputbox "Enter the row value you want to delete:")
        if grep -q "^$rowNumber|" "$file"; then
            if kdialog --yesno "Are you sure you wanna delete data with $rowNumber id?"; then
                sed -i "/^$rowNumber|/d" "$file"
                kdialog --msgbox "Line with ID $rowNumber deleted successfully."
            else
                kdialog --msgbox "Delete cancelled."
            fi
        else
            kdialog --msgbox "Not found in table."
        fi
    else
        kdialog --msgbox "No such table."
    fi
    databaseMenu
}

function updateTable {
    tName=$(kdialog --inputbox "Enter the table name you want to update into:")
    if [[ -f "$tName" ]]; then
        id_to_update=$(kdialog --inputbox "Enter the id you want to update:")
        if grep -q "^$id_to_update|" "$tName"; then
            fileLine=$(head -n 1 "$tName")
            column_names=($(echo "$fileLine" | awk -F'[:|]' '{for (i=1; i<=NF; i+=2) print $i}'))
            kdialog --msgbox "Columns available:\n${column_names[*]}"
            col=$(kdialog --inputbox "Enter the column number you want to update (starting from 1):")
	            col_types=($(echo "$fileLine" | awk -F'[:|]' '{for (i=2; i<=NF; i+=2) print $i}'))
	            newval=$(kdialog --inputbox "Enter the new value:")
	            col_index=$((col - 1))
	            is_valid=true
	            expected_type=${col_types[$col_index]}
	            if [[ $col == 1 ]] && grep -q "^$newval|" "$tName"; then
	                is_valid=false
	                kdialog --msgbox "You can't use this value for the primary key; it already exists."
	            fi
	            case $expected_type in
	                "number")
	                    if [[ ! $newval =~ ^[+-]?[0-9]+$ ]]; then
	                        kdialog --msgbox "Error: '$newval' is not a valid number."
	                        is_valid=false
	                    fi
	                    ;;
	                "date")
	                    if [[ ! $newval =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "$newval" >/dev/null 2>&1; then
	                        kdialog --msgbox "Error: '$newval' is not a valid date (expected format: YYYY-MM-DD)."
	                        is_valid=false
	                    fi
	                    ;;
	                "boolean")
	                    if [[ ! $newval =~ ^(true|false)$ ]]; then
	                        kdialog --msgbox "Error: '$newval' is not a valid boolean (expected: true or false)."
	                        is_valid=false
	                    fi
	                    ;;
	                "string")
	                    # No validation needed for strings
	                    ;;
	                *)
	                    kdialog --msgbox "Error: Unknown data type '$expected_type'."
	                    is_valid=false
	                    ;;
	            esac

			if [[ $is_valid == true ]]; then
			    awk -F'|' -v id="$id_to_update" -v col="$col" -v new="$newval" '{
       			    if ($1 == id) $col = new;
       				 print $0;
   			     }' OFS='|' "$tName" > "$tName.tmp" && mv "$tName.tmp" "$tName"
			    kdialog --msgbox "Update successful!"
			else
			    kdialog --msgbox "Update aborted due to invalid input."
	                fi
          else
	              kdialog --msgbox "ID Not Found!"
	  fi
    else
        kdialog --msgbox "No such table."
    fi
    databaseMenu
}

function databaseMenu {
    opt=$(kdialog --menu "Database Menu:" \
        "1" "Create Table" \
        "2" "List Tables" \
        "3" "Drop Table" \
        "4" "Insert into Table" \
        "5" "Select From Table" \
        "6" "Delete From Table" \
        "7" "Update Table" \
        "8" "Disconnect from database")
    case $opt in
        1) createTable ;;
        2)
            tables=$(ls)
            kdialog --msgbox "$tables"
            databaseMenu
            ;;
        3) dropTable ;;
        4) insertTable ;;
        5) selectTable ;;
        6) deleteFromTable ;;
        7) updateTable ;;
        8) cd .. 
        	mainMenu;;
        *) kdialog --msgbox "Out of Range" 
        	mainMenu ;;
    esac
    mainMenu
}

function mainMenu {
    opt=$(kdialog --menu "Main Menu:" \
        "1" "Create Database" \
        "2" "List Databases" \
        "3" "Connect To Database" \
        "4" "Drop Database" \
        "5" "Exit")
    case $opt in
        1) createDatabase ;;
        2)
            databases=$(ls --ignore="main*")
            kdialog --msgbox "$databases"
            mainMenu
            ;;
        3) connectDatabase ;;
        4) dropDatabase ;;
        5) exit 0 ;;
        *) exit 0 ;;
    esac
}

mainMenu
