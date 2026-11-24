CREATE OR REPLACE PACKAGE BODY IT.PAW_JSON AS
   /******************************************************************************
      NAME:       JSON
      PURPOSE:    Output in JSON format (http://www.json.org) for oracle
              Javascript Simple Object Notation
            
            /!\ the values are encoded according to JSON specifications language.
            Passing an heaxdecimal value in a string must be done with 
            the following syntax :
            
            'someString...someString...#hex[four hexa digits] ... someString...' 
   
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.1        03/07/2007  PGL              1. Created this package body.
   ******************************************************************************/
   /******************************************************************************
   -- TODO
          - Implement a complete function validatejsonobj that parses the object
          and verify its structure.
        - Implement correctly indentation.
        
   ******************************************************************************/
   --------------------------------------------------------------------------------
   -- Internal Types and records
   --------------------------------------------------------------------------------
   -- type for special char table
   TYPE specialCharReplace IS RECORD(
      pattern  VARCHAR(4),
      changeTo VARCHAR2(2));
   TYPE specialChar IS TABLE OF specialCharReplace INDEX BY BINARY_INTEGER;

   --------------------------------------------------------------------------------
   -- Internal variables and constants
   --------------------------------------------------------------------------------
   tSpcChr specialChar;

   x_type_no_defined EXCEPTION;
   msg_type_no_defined CONSTANT VARCHAR2(255) := 'Type of item "%1" not supported in this package.';
   x_invalid_object EXCEPTION;
   msg_invalid_object CONSTANT VARCHAR2(255) := 'Invalid JSON object. Check syntax at item #%1...';

   g_doindetation BOOLEAN := FALSE; -- true for doing indentation

   nullObj JSONStructObj; -- Null JSONObject : never intialized.

   --------------------------------------------------------------------------------
   -- Internal Procedures and functions
   --------------------------------------------------------------------------------

   --------------------------------------------------------------------------------
   -- Procedure that you can customize to print the JSON result string 
   -- in a table, in a file, ont the web with your own procedure, with dbms_output,
   -- ...
   --------------------------------------------------------------------------------
   PROCEDURE my_customized_print(p_str VARCHAR2) IS
   BEGIN
      -- this my customized output comment these line above to put your's.
      --affiche.p(p_str);
   
      dbms_output.put_line(substr(p_str, 1, 500));
      -- htp.p(p_str);
   
      -- end of customization.
   END my_customized_print;

   --------------------------------------------------------------------------------
   -- set the right number of spaces to indent JSON object correctly.
   --------------------------------------------------------------------------------
   PROCEDURE indent(p_what VARCHAR2 DEFAULT '+') IS
   BEGIN
      IF (p_what = '+') THEN
         g_indent := g_indent || g_spc;
      ELSE
         g_indent := substr(g_indent, -length(g_spc));
      END IF;
   END indent;


   --------------------------------------------------------------------------------
   -- returns a boolean converted in a string: true => 'true', false => 'false'
   --------------------------------------------------------------------------------
   FUNCTION bool2str(boolean_in IN BOOLEAN) RETURN VARCHAR2 IS
   BEGIN
      IF (boolean_in) THEN
         RETURN 'true';
      END IF;
      RETURN 'false';
   END bool2str;

   --------------------------------------------------------------------------------
   -- returns true if the string can be converted to a number
   --------------------------------------------------------------------------------
   FUNCTION isNumber(p_str VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
      n NUMBER;
   BEGIN
      n := to_number(p_str);
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END isNumber;

   --------------------------------------------------------------------------------
   -- returns the deencoded string according to JSON encoding specification
   --------------------------------------------------------------------------------
   FUNCTION decodeValue(p_str VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
      my_str VARCHAR2(2000) := p_str;
      i      PLS_INTEGER;
   BEGIN
      i := tSpcChr.first;
      WHILE (i IS NOT NULL)
      LOOP
         -- formating according to JSON specs.
         my_str := REPLACE(my_str, tSpcChr(i).changeTo, tSpcChr(i).pattern);
         i      := tSpcChr.next(i);
      END LOOP;
      -- removing the string delimiter
      IF (substr(my_str, 1, 1) = g_stringDelimiter) THEN
         my_str := substr(my_str, 2);
      END IF;
      IF (substr(my_str, -1) = g_stringDelimiter) THEN
         my_str := substr(my_str, 1, length(my_str) - 1);
      END IF;
      RETURN my_str;
   END decodeValue;

   --------------------------------------------------------------------------------
   -- returns the encoded string according to JSON specification langage
   --------------------------------------------------------------------------------
   FUNCTION formatValue(p_str VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
      my_str VARCHAR2(2000) := p_str;
      i      PLS_INTEGER;
   BEGIN
      -- if the string is null we have to put ''.
      IF (my_str IS NULL) THEN
         my_str := '''''';
      ELSIF (lower(my_str) IN ('true', 'false')) THEN
         -- format a boolean without quote.
         my_str := my_str;
      ELSIF (NOT isNumber(my_str)) THEN
         -- format a string
         i := tSpcChr.first;
         WHILE (i IS NOT NULL)
         LOOP
            -- formating according to JSON specs.
            my_str := REPLACE(my_str, tSpcChr(i).pattern, tSpcChr(i).changeTo);
            i      := tSpcChr.next(i);
         END LOOP;
         -- adding the string delimiter
         my_str := g_stringDelimiter || my_str || g_stringDelimiter;
      ELSE
         -- format a number
         my_str := REPLACE(my_str, ',', '.');
      END IF;
      RETURN my_str;
   END formatValue;

   --------------------------------------------------------------------------------
   -- Returns a JSON Item for our JSON structure 
   --------------------------------------------------------------------------------
   FUNCTION addItem(p_type VARCHAR2, p_item VARCHAR2, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONItem IS
      my_item JSONItem;
   BEGIN
      -- structure controls
      IF (p_type NOT IN
         ('OPENBRACKET', 'OPENHOOK', 'CLOSEBRACKET', 'CLOSEHOOK', 'SEPARATION', 'AFFECTATION', 'ATTRNAME', 'ATTRDATA', 'ARRAYDATA', 'INDENTATION')) THEN
         RAISE x_type_no_defined;
      END IF;
      my_item.type     := p_type;
      my_item.item     := p_item;
      my_item.formated := p_formated;
      RETURN my_item;
   EXCEPTION
      WHEN x_type_no_defined THEN
         print(REPLACE(msg_type_no_defined, '%1', p_type));
         RETURN NULL;
   END addItem;

   --------------------------------------------------------------------------------
   -- opens object
   --------------------------------------------------------------------------------
   FUNCTION openObj RETURN JSONItem IS
   BEGIN
      indent('+');
      RETURN addItem('OPENBRACKET', g_CR || g_objOpenBracket);
   END openObj;

   --------------------------------------------------------------------------------
   -- Closes object
   --------------------------------------------------------------------------------
   FUNCTION closeObj RETURN JSONItem IS
   BEGIN
      indent('-');
      IF (g_doindetation) THEN
         RETURN addItem('CLOSEBRACKET', g_CR || g_objCloseBracket);
      END IF;
      RETURN addItem('CLOSEBRACKET', g_objCloseBracket);
   END closeObj;

   --------------------------------------------------------------------------------
   -- opens array
   --------------------------------------------------------------------------------
   FUNCTION openArray RETURN JSONItem IS
   BEGIN
      RETURN addItem('OPENHOOK', g_arrayOpenBracket);
   END openArray;

   --------------------------------------------------------------------------------
   -- Closes array
   --------------------------------------------------------------------------------
   FUNCTION closeArray RETURN JSONItem IS
   BEGIN
      RETURN addItem('CLOSEHOOK', g_arraycloseBracket);
   END closeArray;


   --------------------------------------------------------------------------------
   -- Inits special char table for coding and decoding value.
   --------------------------------------------------------------------------------
   PROCEDURE initSpecCharTable IS
   BEGIN
      tSpcChr(1).pattern := '\';
      tSpcChr(2).pattern := '/';
      tSpcChr(3).pattern := g_stringDelimiter;
      tSpcChr(4).pattern := chr(8); -- backspace
      tSpcChr(5).pattern := chr(12); -- form feed
      tSpcChr(6).pattern := chr(10); -- new line
      tSpcChr(7).pattern := chr(13); -- carriage return
      tSpcChr(8).pattern := chr(9); -- tablulation
      tSpcChr(9).pattern := '#hex'; -- four hexadecimal digit
      --
      tSpcChr(1).changeTo := '\\';
      tSpcChr(2).changeTo := '\/';
      tSpcChr(3).changeTo := '\' || g_stringDelimiter;
      tSpcChr(4).changeTo := '\b'; -- backspace
      tSpcChr(5).changeTo := '\f'; -- form feed
      tSpcChr(6).changeTo := '\n'; -- new line
      tSpcChr(7).changeTo := '\r'; -- carriage return
      tSpcChr(8).changeTo := '\t'; -- tablulation
      tSpcChr(9).changeTo := '\u'; -- four hexadecimal digit
   END initSpecCharTable;

   --------------------------------------------------------------------------------
   -- Inits package environment.
   --------------------------------------------------------------------------------
   PROCEDURE newJSONObj(p_obj IN OUT NOCOPY JSONStructObj, p_doindetation BOOLEAN DEFAULT TRUE) IS
      i PLS_INTEGER := 1;
   BEGIN
      -- init special char table
      initSpecCharTable;
      -- init json object.
      p_obj.delete;
      IF (p_doindetation) THEN
         g_doindetation := TRUE;
         p_obj(1) := addItem('INDENTATION', g_indent);
         i := 2;
      END IF;
      p_obj(i) := openObj;
   END newJSONObj;

   --------------------------------------------------------------------------------
   -- Returns the first item where the problem is, else return 0
   --------------------------------------------------------------------------------
   FUNCTION validateJSONObj(p_obj IN OUT NOCOPY JSONStructObj, pvalidate BOOLEAN DEFAULT FALSE) RETURN PLS_INTEGER IS
      i               PLS_INTEGER;
      isBracketOpened BOOLEAN := FALSE;
      isHookOpened    BOOLEAN := FALSE;
      x_invalid_structure EXCEPTION;
      IdxElmtErr PLS_INTEGER := 0;
      ------------------------------------------------------------------------
      -- Returns 0 if syntax {...} is correct, else returns the last incorrect 
      -- element.
      ------------------------------------------------------------------------
      FUNCTION validateStructure(p_elmt_type VARCHAR2 DEFAULT 'BRACKET') RETURN NUMBER IS
         cntOpndBrcks PLS_INTEGER := 0;
         x_counter_not_0 EXCEPTION;
      BEGIN
         i := p_obj.first;
         WHILE (i IS NOT NULL)
         LOOP
            CASE p_obj(i).type
               WHEN 'OPEN' || p_elmt_type THEN
                  cntOpndBrcks := cntOpndBrcks + 1;
               WHEN 'CLOSE' || p_elmt_type THEN
                  cntOpndBrcks := cntOpndBrcks - 1;
               ELSE
                  NULL;
            END CASE;
            -- if the counter count down under 0 => structure problem : 
            -- object is already close whether the structure isn't parsed at all.
            IF (cntOpndBrcks < 0) THEN
               RAISE x_counter_not_0;
            END IF;
            i := p_obj.next(i);
         END LOOP;
         -- if the counter is upper than 0 => structure problem : 
         -- one or more brackets still opened. 
         IF (cntOpndBrcks > 0) THEN
            -- when we are here, i is null so initializing i = p_obj.count.
            i := p_obj.count;
            RAISE x_counter_not_0;
         END IF;
         RETURN 0;
      EXCEPTION
         WHEN x_counter_not_0 THEN
            RETURN i;
      END validateStructure;
      ------------------------------------------------------------------------
   BEGIN
      -- see if formatting have to be done 
      i := p_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         IF (NOT p_obj(i).formated AND p_obj(i).type IN ('ATTRNAME', 'ATTRDATA', 'ARRAYDATA')) THEN
            p_obj(i).item := formatValue(p_obj(i).item);
            p_obj(i).formated := TRUE;
         END IF;
         i := p_obj.next(i);
      END LOOP;
   
      --
      -- General Validation : counting and comparing opened and closed brackets and hooks.
      --
      IF (pvalidate) THEN
         IdxElmtErr := validateStructure('BRACKET');
         IF (IdxElmtErr != 0) THEN
            RAISE x_invalid_structure;
         END IF;
         IdxElmtErr := validateStructure('HOOK');
         IF (IdxElmtErr != 0) THEN
            RAISE x_invalid_structure;
         END IF;
         --
      END IF;
      RETURN 0;
   EXCEPTION
      WHEN x_invalid_structure THEN
         RETURN IdxElmtErr;
   END validateJSONObj;

   --------------------------------------------------------------------------------
   -- Closes the JSON Object
   --------------------------------------------------------------------------------
   PROCEDURE closeJSONObj(p_obj IN OUT NOCOPY JSONStructObj) IS
      i      PLS_INTEGER;
      status PLS_INTEGER;
   BEGIN
      -- adding closing bracket
      p_obj(p_obj.last + 1) := closeObj;
      -- when closing object, removing trailing ','
      i := p_obj.last;
      WHILE (i IS NOT NULL)
      LOOP
         IF (p_obj(i).type = 'SEPARATION') THEN
            -- if the futher item of the list is not in these type ('ATTRNAME', 'ATTRDATA', 'ARRAYDATA')
            -- we have to trash the comma.
            IF (p_obj.exists(p_obj.next(i)) AND p_obj(p_obj.next(i)).type NOT IN ('ATTRNAME', 'ATTRDATA', 'ARRAYDATA')) THEN
               p_obj.delete(i);
               EXIT;
            END IF;
         END IF;
         i := p_obj.prior(i);
      END LOOP;
      status := validateJSONObj(p_obj);
      IF (status != 0) THEN
         RAISE x_invalid_object;
      END IF;
   EXCEPTION
      WHEN x_invalid_object THEN
         print(REPLACE(msg_invalid_object, '%1', status));
   END closeJSONObj;


   --------------------------------------------------------------------------------
   -- modify a JSON object to remove indentation elements
   --------------------------------------------------------------------------------
   FUNCTION removeIndent(p_obj JSONStructObj) RETURN JSONStructObj IS
      my_obj JSONStructObj := p_obj;
      i      PLS_INTEGER;
   BEGIN
      i := my_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         IF (my_obj(i).type = 'INDENTATION') THEN
            my_obj.delete(i);
         END IF;
         i := my_obj.next(i);
      END LOOP;
      RETURN my_obj;
   END removeIndent;


   --------------------------------------------------------------------------------
   -- Returns a the values of an array in varchar2 type from the JSON Structure
   --------------------------------------------------------------------------------
   FUNCTION getComplexValue(p_obj JSONStructObj, pidx PLS_INTEGER, p_ArrayOrObject VARCHAR2) RETURN VARCHAR2 IS
      my_obj            JSONStructObj := p_obj;
      ln_count_OpenHook PLS_INTEGER := 1;
      my_value          VARCHAR2(32000);
      j                 PLS_INTEGER := pidx;
      lv_what           VARCHAR2(10);
   BEGIN
      -- see what we are attempting to retrieve...
      IF (p_ArrayOrObject = 'ARRAY') THEN
         lv_what := 'HOOK';
      ELSE
         lv_what := 'BRACKET';
      END IF;
      --
      WHILE (j IS NOT NULL)
      LOOP
         IF (my_obj(j).type = 'OPEN' || lv_what) THEN
            ln_count_OpenHook := ln_count_OpenHook + 1;
         ELSIF (my_obj(j).type = 'CLOSE' || lv_what) THEN
            ln_count_OpenHook := ln_count_OpenHook - 1;
         END IF;
         my_value := my_value || my_obj(j).item;
         IF (ln_count_OpenHook = 0) THEN
            my_value := substr(my_value, 1, length(my_value) - 1);
            EXIT;
         END IF;
         j := my_obj.next(j);
      END LOOP;
      RETURN my_value;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END getComplexValue;

   --------------------------------------------------------------------------------
   -- Set a value to an attribut
   --------------------------------------------------------------------------------
   FUNCTION setAttrSimpleValue(p_obj JSONStructObj, pname VARCHAR2, pvalue VARCHAR2, pformated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
      my_obj      JSONStructObj := p_obj;
      i           PLS_INTEGER;
      j           PLS_INTEGER;
      value_found BOOLEAN := FALSE;
   BEGIN
      i := my_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         IF (lower(my_obj(i).item) = g_stringDelimiter || lower(pname) || g_stringDelimiter AND my_obj(i).type = 'ATTRNAME') THEN
            -- the arrtibute exists.
            j := my_obj.next(i);
            WHILE (j IS NOT NULL)
            LOOP
               IF (my_obj(j).type = 'ATTRDATA') THEN
                  -- we have found the value to be replaced
                  IF (pformated) THEN
                     my_obj(j).item := pvalue;
                  ELSE
                     my_obj(j).item := formatValue(pvalue);
                  END IF;
                  my_obj(j).formated := NOT pformated;
                  -- exiting this loop;
                  value_found := TRUE;
                  EXIT;
               END IF;
               j := my_obj.next(j);
            END LOOP;
         END IF;
         IF (value_found) THEN
            EXIT;
         END IF;
         i := my_obj.next(i);
      END LOOP;
      RETURN my_obj;
   END setAttrSimpleValue;

   --------------------------------------------------------------------------------
   -- Set a value to an attribut
   --------------------------------------------------------------------------------
   FUNCTION setAttrSimpleValue(p_obj JSONStructObj, pname VARCHAR2, pbool BOOLEAN, pformated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
      val VARCHAR2(10) := bool2str(pbool);
   BEGIN
      RETURN setAttrSimpleValue(p_obj, pname, val, pformated);
   END setAttrSimpleValue;

   --------------------------------------------------------------------------------
   -- Returns a JSON object with a varchar2 value
   --------------------------------------------------------------------------------
   FUNCTION getAttrValue(p_obj JSONStructObj, pname VARCHAR2, pdecode BOOLEAN DEFAULT TRUE) RETURN VARCHAR2 IS
      my_obj JSONStructObj := p_obj;
      i      PLS_INTEGER;
      -----------------------------------------------------------------
      FUNCTION returnvalue(pidx PLS_INTEGER, pdec BOOLEAN DEFAULT TRUE) RETURN VARCHAR2 IS
         j             PLS_INTEGER := pidx;
         FirstNextVal  PLS_INTEGER := my_obj.next(j);
         SecondNextVal PLS_INTEGER := my_obj.next(FirstNextVal);
         ThirdNextVal  PLS_INTEGER := my_obj.next(SecondNextVal);
         -- due to removing INDENTATION, the index may not be 2,3,4,5... but 2,4,5,8,...
         -- so we can't access to the structure with j, j+1, j+2,... 
         -- We'd better access by j, my_obj.next(j), my_obj.next(my_obj.next(j)), ...
         my_tab_value VARCHAR2(32000);
      BEGIN
         IF (my_obj(j).type = 'ATTRNAME') THEN
            -- see if the value is a table, an object or a simple value.
            IF (my_obj(SecondNextVal).type = 'ATTRDATA') THEN
               -- this is a simple attribut
               IF (pdec) THEN
                  initSpecCharTable;
                  my_tab_value := decodeValue(my_obj(SecondNextVal).item);
               ELSE
                  my_tab_value := my_obj(SecondNextVal).item;
               END IF;
            ELSIF (my_obj(SecondNextVal).type = 'OPENHOOK') THEN
               -- This is a table
               -- from ThirdNextVal to first closing hook for this level [...[...]...], extracting array values
               my_tab_value := getComplexValue(my_obj, ThirdNextVal, 'ARRAY');
            ELSIF (my_obj(SecondNextVal).type = 'OPENBRACKET') THEN
               -- This is an object
               -- from ThirdNextVal to first closing hook for this level {...{...}...}, extracting object values
               my_tab_value := getComplexValue(my_obj, ThirdNextVal, 'OBJECT');
            END IF;
            RETURN my_tab_value;
         ELSE
            -- not an ATTRNAME returning null
            RETURN NULL;
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            RETURN NULL;
      END returnvalue;
      ----------------------------------------------------------------
   BEGIN
      -- remove indentation
      my_obj := removeIndent(my_obj);
      i      := my_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         IF (upper(my_obj(i).item) = upper(g_stringDelimiter || pname || g_stringDelimiter)) THEN
            RETURN returnvalue(i, pdecode);
         END IF;
         i := my_obj.next(i);
      END LOOP;
      -- if we go here, the value for pname doesn't exist in p_obj.
      RETURN NULL;
   EXCEPTION
      WHEN no_data_found THEN
         RETURN NULL;
   END getAttrValue;


   --------------------------------------------------------------------------------
   -- Returns a JSON object with a varchar2 value
   --------------------------------------------------------------------------------
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, v VARCHAR2, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
      my_obj JSONStructObj := p_obj;
   BEGIN
      IF (g_doindetation) THEN
         my_obj(my_obj.last + 1) := addItem('INDENTATION', g_CR || g_indent);
      END IF;
      my_obj(my_obj.last + 1) := addItem('ATTRNAME', n);
      my_obj(my_obj.last + 1) := addItem('AFFECTATION', g_Affectation);
      my_obj(my_obj.last + 1) := addItem('ATTRDATA', v, p_formated);
      my_obj(my_obj.last + 1) := addItem('SEPARATION', g_separation);
      RETURN my_obj;
   END addAttr;

   --------------------------------------------------------------------------------
   -- Returns a JSON object with a boolean value
   --------------------------------------------------------------------------------
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, pbool BOOLEAN, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
      val VARCHAR2(10) := bool2str(pbool);
   BEGIN
      RETURN addAttr(p_obj, n, val, p_formated);
   END addAttr;


   --------------------------------------------------------------------------------
   -- Returns a JSON object : The value could be an object
   --------------------------------------------------------------------------------
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, p_objValue JSONStructObj) RETURN JSONStructObj IS
      my_obj JSONStructObj := p_obj;
      i      PLS_INTEGER;
   BEGIN
      IF (g_doindetation) THEN
         my_obj(my_obj.last + 1) := addItem('INDENTATION', g_CR || g_indent);
      END IF;
      my_obj(my_obj.last + 1) := addItem('ATTRNAME', n);
      my_obj(my_obj.last + 1) := addItem('AFFECTATION', g_Affectation);
      i := p_objValue.first;
      WHILE (i IS NOT NULL)
      LOOP
         my_obj(my_obj.last + 1) := addItem(p_objValue(i).type, p_objValue(i).item, p_objValue(i).formated);
         i := p_objValue.next(i);
      END LOOP;
      my_obj(my_obj.last + 1) := addItem('SEPARATION', g_separation);
      RETURN my_obj;
   END addAttr;

   --------------------------------------------------------------------------------
   -- Returns a JSON array of a plsql table (JSONArray type)
   --------------------------------------------------------------------------------
   FUNCTION addArray(p_obj JSONStructObj, p_table JSONArray, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
      my_obj JSONStructObj := p_obj;
      i      PLS_INTEGER;
      j      PLS_INTEGER;
   BEGIN
      j := my_obj.first;
      -- if no object has been passed, that because the array is embeded
      IF (j IS NULL) THEN
         j := 1;
      ELSE
         j := my_obj.last + 1;
      END IF;
      --
      --my_obj(j) := addItem('INDENTATION', g_CR || g_indent);
      my_obj(j) := openArray;
      i := p_table.first;
      j := my_obj.last + 1;
      WHILE (i IS NOT NULL)
      LOOP
         IF (i != p_table.first) THEN
            my_obj(j) := addItem('SEPARATION', g_separation);
            j := j + 1;
         END IF;
         my_obj(j) := addItem('ARRAYDATA', p_table(i), p_formated);
         j := j + 1;
         i := p_table.next(i);
      END LOOP;
      my_obj(my_obj.last + 1) := closeArray;
      RETURN my_obj;
   END addArray;

   --------------------------------------------------------------------------------
   -- Returns a JSON array 
   --------------------------------------------------------------------------------
   FUNCTION addArray(p_tab JSONArray, p_format BOOLEAN DEFAULT FALSE) RETURN JSONStructObj IS
   BEGIN
      RETURN addArray(p_obj => nullObj, p_table => p_tab, p_formated => p_format);
   END addArray;


   --------------------------------------------------------------------------------
   -- Returns the JSON object into a string
   --------------------------------------------------------------------------------
   FUNCTION JSON2String(p_obj IN OUT NOCOPY JSONStructObj, p_only_an_array BOOLEAN DEFAULT FALSE) RETURN VARCHAR2 IS
      i        PLS_INTEGER;
      myStrObj VARCHAR2(32000);
   BEGIN
      IF (p_only_an_array) THEN
         -- the object only contains an array so remove { and }.
         i := p_obj.first;
         WHILE (i IS NOT NULL)
         LOOP
            IF (p_obj(i).type = 'OPENBRACKET') THEN
               p_obj.delete(i);
               EXIT;
            END IF;
            i := p_obj.next(i);
         END LOOP;
         --
         i := p_obj.last;
         WHILE (i IS NOT NULL)
         LOOP
            IF (p_obj(i).type = 'CLOSEBRACKET') THEN
               p_obj.delete(i);
               EXIT;
            END IF;
            i := p_obj.prior(i);
         END LOOP;
      END IF;
      --
      i := p_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         myStrObj := myStrObj || p_obj(i).item;
         i        := p_obj.next(i);
      END LOOP;
      RETURN myStrObj;
   END JSON2String;

   --------------------------------------------------------------------------------
   -- Returns a JSON object with a string
   --------------------------------------------------------------------------------
   FUNCTION String2JSON(p_str VARCHAR2, pStrDelimiter VARCHAR2 DEFAULT g_stringDelimiter) RETURN JSONStructObj IS
      Obj         JSONStructObj;
      tmpStr      VARCHAR2(32000) := p_str;
      buf         VARCHAR2(32000);
      i           PLS_INTEGER := 1;
      CutPosition PLS_INTEGER := 1;
      my_tabTmp   JSONArray;
      x_bad_JSONstruct EXCEPTION;
   
      haveSeen_attrname BOOLEAN := FALSE;
      we_are_in_a_table BOOLEAN := FALSE;
      chrTmp            VARCHAR2(1);
      typeTmp           VARCHAR2(20);
      itemTmp           VARCHAR2(2000);
   BEGIN
      -- defining string delimiter 
      g_stringDelimiter := pStrDelimiter;
   
      -- formatting the string 
      -- suppress CR
      tmpStr := REPLACE(tmpStr, g_CR, ' ');
   
      -- suppress indentation
      WHILE (instr(tmpStr, '  ') > 0)
      LOOP
         tmpStr := REPLACE(tmpStr, '  ', ' ');
      END LOOP;
   
      --replace backSlash + StringDelimiter whit a sequence of easy identifiable characters 
      tmpStr := REPLACE(tmpStr, '\' || g_stringDelimiter, '\§');
   
      -- turning the spacing before and afters symbols to null
      g_objOpenBracket    := REPLACE(g_objOpenBracket, ' ', NULL);
      g_objcloseBracket   := REPLACE(g_objcloseBracket, ' ', NULL);
      g_arrayOpenBracket  := REPLACE(g_arrayOpenBracket, ' ', NULL);
      g_arrayCloseBracket := REPLACE(g_arrayCloseBracket, ' ', NULL);
      g_Affectation       := REPLACE(g_Affectation, ' ', NULL);
      g_separation        := REPLACE(g_separation, ' ', NULL);
   
      i := 1;
      WHILE (length(tmpStr) > 0 AND i < 100)
      LOOP
         -- removing first spaces
         WHILE (substr(tmpStr, 1, 1) = ' ')
         LOOP
            tmpStr := substr(tmpStr, 2, length(tmpStr));
         END LOOP;
         -- now : it's ' or { or [
         chrTmp := substr(tmpStr, 1, 1);
         IF (chrTmp = g_objOpenBracket) THEN
            Obj(i) := openObj;
            haveSeen_attrname := FALSE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_arrayOpenBracket) THEN
            Obj(i) := openArray;
            we_are_in_a_table := TRUE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_objCloseBracket) THEN
            Obj(i) := closeObj;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_arrayCloseBracket) THEN
            Obj(i) := closeArray;
            we_are_in_a_table := FALSE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_stringDelimiter) THEN
            -- we must be carful because the string delimiter may be predeced by a '\'.
            -- In this cas, this is not a string delimiter !
            IF (haveSeen_attrname OR we_are_in_a_table) THEN
               IF (haveSeen_attrname) THEN
                  typeTmp           := 'ATTRDATA';
                  haveSeen_attrname := FALSE;
               END IF;
               IF (we_are_in_a_table) THEN
                  typeTmp := 'ARRAYDATA';
               END IF;
            ELSE
               typeTmp           := 'ATTRNAME';
               haveSeen_attrname := TRUE;
            END IF;
            Obj(i) := addItem(typeTmp, substr(tmpStr, 1, instr(tmpStr, g_stringDelimiter, 2)), TRUE);
            tmpStr := substr(tmpStr, instr(tmpStr, g_stringDelimiter, 2) + 1);
         
         ELSIF (chrTmp = g_Affectation) THEN
            Obj(i) := addItem('AFFECTATION', g_Affectation, FALSE);
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_separation) THEN
            Obj(i) := addItem('SEPARATION', g_separation, FALSE);
            tmpStr := substr(tmpStr, 2);
         
         ELSE
            -- if the data is a number, there's no string delimiter
            IF (haveSeen_attrname OR we_are_in_a_table) THEN
               IF (haveSeen_attrname) THEN
                  typeTmp           := 'ATTRDATA';
                  haveSeen_attrname := FALSE;
               END IF;
               IF (we_are_in_a_table) THEN
                  typeTmp := 'ARRAYDATA';
               END IF;
               -- see if we are at the end of a table or an objet => no separation !
               IF (instr(tmpStr, g_separation, 1) = 0) THEN
                  IF (instr(tmpStr, g_arrayCloseBracket, 1) = 0) THEN
                     IF (instr(tmpStr, g_objCloseBracket, 1) = 0) THEN
                        -- bad struture !
                        RAISE x_bad_JSONstruct;
                     ELSE
                        -- last data before ending an object
                        itemTmp := substr(tmpStr, 1, instr(tmpStr, g_objCloseBracket, 1) - 1);
                        tmpStr  := substr(tmpStr, instr(tmpStr, g_objCloseBracket, 1));
                     END IF;
                  ELSE
                     -- last data before ending an array
                     itemTmp := substr(tmpStr, 1, instr(tmpStr, g_arrayCloseBracket, 1) - 1);
                     tmpStr  := substr(tmpStr, instr(tmpStr, g_arrayCloseBracket, 1));
                  END IF;
               ELSE
                  -- Some data
                  itemTmp := substr(tmpStr, 1, instr(tmpStr, g_separation, 1) - 1);
                  tmpStr  := substr(tmpStr, instr(tmpStr, g_separation, 1));
               END IF;
            
               Obj(i) := addItem(typeTmp, REPLACE(itemTmp, '\§', '\' || g_stringDelimiter), TRUE);
            
            END IF;
         
         END IF;
         i := i + 1;
      END LOOP;
   
      RETURN Obj;
   EXCEPTION
      WHEN x_bad_JSONstruct THEN
         print('Bad JSON structure : missing "' || g_objOpenBracket || '" or "' || g_objCloseBracket || '".');
         RETURN nullObj;
   END String2JSON;

   --------------------------------------------------------------------------------
   -- Returns a JSON object with a string
   --------------------------------------------------------------------------------
   FUNCTION CLOB2JSON(p_str CLOB, pStrDelimiter VARCHAR2 DEFAULT g_stringDelimiter) RETURN JSONStructObj IS
      Obj    JSONStructObj;
      tmpStr CLOB := p_str;
      --buf varchar2(32000);
      i           PLS_INTEGER := 1;
      CutPosition PLS_INTEGER := 1;
      my_tabTmp   JSONArray;
      x_bad_JSONstruct EXCEPTION;
   
      haveSeen_attrname BOOLEAN := FALSE;
      we_are_in_a_table BOOLEAN := FALSE;
      chrTmp            VARCHAR2(1);
      typeTmp           VARCHAR2(20);
      itemTmp           VARCHAR2(2000);
   BEGIN
      -- defining string delimiter 
      g_stringDelimiter := pStrDelimiter;
   
      -- formatting the string 
      -- suppress CR
      tmpStr := REPLACE(tmpStr, g_CR, ' ');
   
      -- suppress indentation
      WHILE (instr(tmpStr, '  ') > 0)
      LOOP
         tmpStr := REPLACE(tmpStr, '  ', ' ');
      END LOOP;
   
      --replace backSlash + StringDelimiter whit a sequence of easy identifiable characters 
      tmpStr := REPLACE(tmpStr, '\' || g_stringDelimiter, '\§');
   
      -- turning the spacing before and afters symbols to null
      g_objOpenBracket    := REPLACE(g_objOpenBracket, ' ', NULL);
      g_objcloseBracket   := REPLACE(g_objcloseBracket, ' ', NULL);
      g_arrayOpenBracket  := REPLACE(g_arrayOpenBracket, ' ', NULL);
      g_arrayCloseBracket := REPLACE(g_arrayCloseBracket, ' ', NULL);
      g_Affectation       := REPLACE(g_Affectation, ' ', NULL);
      g_separation        := REPLACE(g_separation, ' ', NULL);
   
      i := 1;
      WHILE (length(tmpStr) > 0 AND i < 100)
      LOOP
         -- removing first spaces
         WHILE (substr(tmpStr, 1, 1) = ' ')
         LOOP
            tmpStr := substr(tmpStr, 2, length(tmpStr));
         END LOOP;
         -- now : it's ' or { or [
         chrTmp := substr(tmpStr, 1, 1);
         IF (chrTmp = g_objOpenBracket) THEN
            Obj(i) := openObj;
            haveSeen_attrname := FALSE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_arrayOpenBracket) THEN
            Obj(i) := openArray;
            we_are_in_a_table := TRUE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_objCloseBracket) THEN
            Obj(i) := closeObj;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_arrayCloseBracket) THEN
            Obj(i) := closeArray;
            we_are_in_a_table := FALSE;
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_stringDelimiter) THEN
            -- we must be carful because the string delimiter may be predeced by a '\'.
            -- In this cas, this is not a string delimiter !
            IF (haveSeen_attrname OR we_are_in_a_table) THEN
               IF (haveSeen_attrname) THEN
                  typeTmp           := 'ATTRDATA';
                  haveSeen_attrname := FALSE;
               END IF;
               IF (we_are_in_a_table) THEN
                  typeTmp := 'ARRAYDATA';
               END IF;
            ELSE
               typeTmp           := 'ATTRNAME';
               haveSeen_attrname := TRUE;
            END IF;
            Obj(i) := addItem(typeTmp, substr(tmpStr, 1, instr(tmpStr, g_stringDelimiter, 2)), TRUE);
            tmpStr := substr(tmpStr, instr(tmpStr, g_stringDelimiter, 2) + 1);
         
         ELSIF (chrTmp = g_Affectation) THEN
            Obj(i) := addItem('AFFECTATION', g_Affectation, FALSE);
            tmpStr := substr(tmpStr, 2);
         
         ELSIF (chrTmp = g_separation) THEN
            Obj(i) := addItem('SEPARATION', g_separation, FALSE);
            tmpStr := substr(tmpStr, 2);
         
         ELSE
            -- if the data is a number, there's no string delimiter
            IF (haveSeen_attrname OR we_are_in_a_table) THEN
               IF (haveSeen_attrname) THEN
                  typeTmp           := 'ATTRDATA';
                  haveSeen_attrname := FALSE;
               END IF;
               IF (we_are_in_a_table) THEN
                  typeTmp := 'ARRAYDATA';
               END IF;
               -- see if we are at the end of a table or an objet => no separation !
               IF (instr(tmpStr, g_separation, 1) = 0) THEN
                  IF (instr(tmpStr, g_arrayCloseBracket, 1) = 0) THEN
                     IF (instr(tmpStr, g_objCloseBracket, 1) = 0) THEN
                        -- bad struture !
                        RAISE x_bad_JSONstruct;
                     ELSE
                        -- last data before ending an object
                        itemTmp := substr(tmpStr, 1, instr(tmpStr, g_objCloseBracket, 1) - 1);
                        tmpStr  := substr(tmpStr, instr(tmpStr, g_objCloseBracket, 1));
                     END IF;
                  ELSE
                     -- last data before ending an array
                     itemTmp := substr(tmpStr, 1, instr(tmpStr, g_arrayCloseBracket, 1) - 1);
                     tmpStr  := substr(tmpStr, instr(tmpStr, g_arrayCloseBracket, 1));
                  END IF;
               ELSE
                  -- Some data
                  itemTmp := substr(tmpStr, 1, instr(tmpStr, g_separation, 1) - 1);
                  tmpStr  := substr(tmpStr, instr(tmpStr, g_separation, 1));
               END IF;
            
               Obj(i) := addItem(typeTmp, REPLACE(itemTmp, '\§', '\' || g_stringDelimiter), TRUE);
            
            END IF;
         
         END IF;
         i := i + 1;
      END LOOP;
   
      RETURN Obj;
   EXCEPTION
      WHEN x_bad_JSONstruct THEN
         print('Bad JSON structure : missing "' || g_objOpenBracket || '" or "' || g_objCloseBracket || '".');
         RETURN nullObj;
   END CLOB2JSON;
   --------------------------------------------------------------------------------
   -- Printing output
   --------------------------------------------------------------------------------
   PROCEDURE print(p_str VARCHAR2) IS
   BEGIN
      IF (g_output_type = 'WEB') THEN
         htp.p(p_str);
      ELSE
         -- Here is the hook for your customized output.
         my_customized_print(p_str);
      END IF;
   END print;


   --------------------------------------------------------------------------------
   -- Dumping pl/sql structure using print routine.
   --------------------------------------------------------------------------------
   PROCEDURE HTMLdumpJSONObj(p_obj IN OUT NOCOPY JSONStructObj) IS
      i PLS_INTEGER;
   BEGIN
      print('<style>
	#dump {font-size:9px;}
	#dump table {border:1px dashed #cccccc;}
	#dump table tr td{text-align:center;}
	#idx {color:red;font-size:7px;}
	#type {color:green;font-size:7px;}
	#formated {color:blue;}
	#item {color:black; font-weight:bold; font-size:11px;}
	</style>');
      print('<table id="dump"><tr>');
      i := p_obj.first;
      WHILE (i IS NOT NULL)
      LOOP
         print('<td><table>');
         print('<tr><td id="idx">' || i || '</td></tr>');
         print('<tr><td id="type">' || p_obj(i).type || '</td></tr>');
         print('<tr><td id="formated">' || bool2str(p_obj(i).formated) || '</td></tr>');
         print('<tr><td id="item">' || p_obj(i).item || '</td></tr>');
         print('</table></td>');
         i := p_obj.next(i);
      END LOOP;
      print('</tr></table>');
   END HTMLdumpJSONObj;

   --------------------------------------------------------------------------------
   -- Printing the version of this package
   --------------------------------------------------------------------------------
   FUNCTION getVersion RETURN VARCHAR2 IS
   BEGIN
      RETURN g_package_version;
   END getVersion;

   --------------------------------------------------------------------------------
   -- Testing this package
   --------------------------------------------------------------------------------
   PROCEDURE test IS
      my_str      VARCHAR2(255) := '", ' || chr(8) || ', ' || chr(9) || ', ' || chr(10) || ', ' || chr(12) || ', ' || chr(13) || ', /, \, #hexABCD ';
      my_tab      JSONArray;
      my_obj      JSONStructObj;
      my_obj2     JSONStructObj;
      my_objInStr VARCHAR2(2000);
   BEGIN
      print('<h2>JSON PL/SQL Package - ' || getVersion || '</h2>');
      --
      -- Value encoded
      --
      newJSONObj(my_obj);
      Print('<hr><h5>Testing the decoder</h5><br>');
      Print('values => ' || my_str || '<br>');
      Print('encoded values => ' || formatValue(my_str));
      --
      -- simple object
      --
      Print('<hr><h5>simple object</h5><br>');
      newJSONObj(my_obj);
      my_obj := addAttr(my_obj, 'FirstName', 'Pierre-Gilles/"levallois"\');
      my_obj := addAttr(my_obj, 'UserID', '1234');
      closeJSONObj(my_obj);
      print(JSON2String(my_obj));
      print('<br>');
      HTMLdumpJSONObj(my_obj);
      --
      -- Simple table
      --
      Print('<hr><h5>simple table</h5><br>');
      my_tab(1) := 'a';
      my_tab(my_tab.last + 1) := 'b';
      my_tab(my_tab.last + 1) := 'c';
      my_tab(my_tab.last + 1) := 'd';
      my_tab(my_tab.last + 1) := '1';
      my_tab(my_tab.last + 1) := '2';
      my_tab(my_tab.last + 1) := '3';
      my_tab(my_tab.last + 1) := '-1,1';
      my_tab(my_tab.last + 1) := '2e2';
      newJSONObj(my_obj);
      my_obj := addArray(my_obj, my_tab);
      closeJSONObj(my_obj);
      print(JSON2String(my_obj, TRUE));
      --
      -- Complex object
      --
      print('<hr><h5>Complex object</h5><br>');
      newJSONObj(my_obj);
      my_obj := addAttr(my_obj, 'Table', addArray(my_tab));
      closeJSONObj(my_obj);
      print(JSON2String(my_obj));
      --
      -- Complex object 2
      --  
      print('<hr><h5>Complex object 2</h5><br>');
      newJSONObj(my_obj);
      my_obj := addAttr(my_obj, 'UserID', '1234');
      my_obj := addAttr(my_obj, 'Table', addArray(my_tab));
      newJSONObj(my_obj2);
      my_obj2 := addAttr(my_obj2, 'email', 'me@mydomin.com');
      my_obj2 := addAttr(my_obj2, 'adr', '1, rue de Paris 69001 Lyon');
      closeJSONObj(my_obj2);
      my_obj := addAttr(my_obj, 'Addresses', my_obj2);
      closeJSONObj(my_obj);
      print(JSON2String(my_obj));
      --
      -- testing Decoding function
      --
      print('<hr><h5>testing Decoding function</h5><br>');
      print('<hr>Object is :');
      print(JSON2String(my_obj) || '<br>');
      HTMLdumpJSONObj(my_obj);
      print('<hr>Trying to get UserID''s value with getAttrValue() : <br>');
      print(getAttrValue(my_obj, 'UserID'));
      print('<br>Trying to get adr''s value with getAttrValue() : <br>');
      print(getAttrValue(my_obj, 'adr'));
      print('<br>Trying to get a table with getAttrValue() : <br>');
      print(getAttrValue(my_obj, 'table'));
      print('<br>Trying to get an object (Addresses) with getAttrValue() : <br>');
      print(getAttrValue(my_obj, 'Addresses'));
   
      print('<hr><h5>testing setAttrSimpleValue</h5><br>');
      print('<br>Trying to set UserID''s value with "4321" :<br>');
      my_obj := setAttrSimpleValue(my_obj, 'UserID', '4321');
      HTMLdumpJSONObj(my_obj);
      print('<br>Trying to set email''s value with "webmaster@laclasse.com" :<br>');
      my_obj := setAttrSimpleValue(my_obj, 'email', 'webmaster@laclasse.com');
      HTMLdumpJSONObj(my_obj);
   
      --
      --   Testing String2JSON
      --
      Print('<hr><h5>Testing the deserializer String2JSON</h5><br>');
      --   newJSONObj(my_obj, false);
      --   my_obj := addAttr(my_obj, 'FirstName', 'Pierre-Gilles /"levallois"\');
      --   my_obj := addAttr(my_obj, 'LastName', 'Levallois');
      --   my_obj := addAttr(my_obj, 'UserID', '1234');
      --   my_obj := addAttr(my_obj, 'Addresses', my_obj2);
      --   my_obj := addAttr(my_obj, 'Table', addArray(my_tab));
      --   closeJSONObj(my_obj);
      --   print(JSON2String(my_obj));
      --   print('<br>Here is the object before calling String2JSON<br>');
      --   my_obj := removeIndent(my_obj);
      --   HTMLdumpJSONObj(my_obj);
      --   my_objInStr := JSON2String(my_obj);
      my_objInStr := '{"id":"25820","img":"picto_img.gif","checksum":"8744","txt":"<a href=\"javascript:go2(25820, ''597f5f4533730c881ddd96d4b8d63e02'');\" class=\"docUrlF\">test</a>","nature":"ELT","draggable":1,"imgopen":"folderopen.gif","imgclose":"folder.gif","imgselected":"page.gif","imgopenselected":"folderopen.gif","imgcloseselected":"folder.gif","open":true,"check":0,"canhavechildren":false,"acceptdrop":true,"last":false,"editable":true,"checkbox":true,"ondropajax":true,"droplink":"http://ias.erasme.lan/pls/education/!ajax_server.service?serviceName=service_deplacer&p_rendertype=none"}';
      print(my_objInStr || '<br>');
      my_obj := String2JSON(my_objInStr, '"');
      print('Here is the object after calling String2JSON<br>');
      HTMLdumpJSONObj(my_obj);
      print('<hr>Trying to get nature''s value with getAttrValue() : <br>');
      print(getAttrValue(my_obj, 'nature'));
      --
      -- Testing validation function
      --
      print('<hr><h5>testing validation function</h5><br>');
      my_objInStr := '{"id":"25820","img":"picto_img.gif"';
      print('Here is an incorrect Json Object : ' || my_objInStr || '<br>');
      my_obj := String2JSON(my_objInStr, '"');
      HTMLdumpJSONObj(my_obj);
      print('Now calling validateJSONObj<br>');
      print('Result of json validation : ' || validateJSONObj(my_obj));
   
      my_objInStr := '"id":"25820","img":"picto_img.gif"}';
      print('<br>Here is an incorrect Json Object : ' || my_objInStr || '<br>');
      my_obj := String2JSON(my_objInStr, '"');
      HTMLdumpJSONObj(my_obj);
      print('Now calling validateJSONObj<br>');
      print('Result of json validation : ' || validateJSONObj(my_obj));
   
      my_objInStr := '{"id":"25820","img": ["picto_img.gif",}';
      print('<br>Here is an incorrect Json Object : ' || my_objInStr || '<br>');
      my_obj := String2JSON(my_objInStr, '"');
      HTMLdumpJSONObj(my_obj);
      print('Now calling validateJSONObj<br>');
      print('Result of json validation : ' || validateJSONObj(my_obj));
   
      my_objInStr := '{"id":"25820","img": "picto_img.gif"]}';
      print('<br>Here is an incorrect Json Object : ' || my_objInStr || '<br>');
      my_obj := String2JSON(my_objInStr, '"');
      HTMLdumpJSONObj(my_obj);
      print('Now calling validateJSONObj<br>');
      print('Result of json validation : ' || validateJSONObj(my_obj));
   
   END test;

END PAW_JSON;
/

