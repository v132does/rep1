CREATE OR REPLACE PACKAGE IT.PAW_JSON AS
   /******************************************************************************
      NAME:       JSON
      PURPOSE:
   
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        03/07/2007             1. Created this package.
   ******************************************************************************/
   --------------------------------------------------------------------------------
   -- Global Types and records 
   --------------------------------------------------------------------------------
   -- type for JSON Array
   TYPE JSONArray IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;

   -- type for all Name/Value Couples in JSON
   TYPE gr_JSONnvCouple IS RECORD(
      NAME  VARCHAR2(255),
      VALUE VARCHAR2(2000));

   -- Type for the final JSON generated string
   TYPE JSONItem IS RECORD(
      TYPE VARCHAR2(100), -- OPENBRACKET, OPENHOOK, CLOSEBRACKET, CLOSEHOOK, 
      -- SEPARATION, AFFECTATION, ATTRNAME, ATTRDATA, ARRAYDATA
      -- INDENTATION
      item     VARCHAR2(2000), -- the attribute name or value.
      formated BOOLEAN DEFAULT FALSE); -- true if "item" has been already formatted.          
   TYPE JSONStructObj IS TABLE OF JSONItem INDEX BY BINARY_INTEGER;

   --------------------------------------------------------------------------------
   -- Global variables and constants
   --------------------------------------------------------------------------------
   -- Output redirection. Possibles values are 
   --      -> 'WEB' (via Oracle htp/htf toolkit) Default
   --      -> 'CUSTO' (Your custom output)
   g_output_type CONSTANT VARCHAR2(10) := 'CUSTO';

   -- 
   g_objOpenBracket    VARCHAR2(2) := '{ ';
   g_objcloseBracket   VARCHAR2(2) := ' }';
   g_arrayOpenBracket  VARCHAR2(2) := '[ ';
   g_arraycloseBracket VARCHAR2(2) := ' ]';
   g_stringDelimiter   VARCHAR2(1) := '''';
   g_Affectation       VARCHAR2(3) := ' : ';
   g_separation        VARCHAR2(3) := ', ';
   g_CR                VARCHAR2(1) := Chr(10); -- used to indent the JSON object correctly
   g_spc               VARCHAR2(2) := '  '; -- used to indent the JSON object correctly

   g_indent VARCHAR2(2000) := NULL; -- count the recursive imbrications for object 
   -- +2 spaces when calling openObj 
   -- -2 spaces when calling closeObj

   g_package_version CONSTANT VARCHAR2(100) := '1.0 Stable';
   --------------------------------------------------------------------------------
   -- Public proc. and  funct. signatures
   --------------------------------------------------------------------------------
   PROCEDURE newJSONObj(p_obj IN OUT NOCOPY JSONStructObj, p_doindetation BOOLEAN DEFAULT TRUE);
   PROCEDURE closeJSONObj(p_obj IN OUT NOCOPY JSONStructObj);
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, v VARCHAR2, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, pbool BOOLEAN, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION addAttr(p_obj JSONStructObj, n VARCHAR2, p_objValue JSONStructObj) RETURN JSONStructObj;
   FUNCTION addArray(p_tab JSONArray, p_format BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION addArray(p_obj JSONStructObj, p_table JSONArray, p_formated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION JSON2String(p_obj IN OUT NOCOPY JSONStructObj, p_only_an_array BOOLEAN DEFAULT FALSE) RETURN VARCHAR2;
   FUNCTION CLOB2JSON(p_str CLOB, pStrDelimiter VARCHAR2 DEFAULT g_stringDelimiter) RETURN JSONStructObj;
   FUNCTION String2JSON(p_str VARCHAR2, pStrDelimiter VARCHAR2 DEFAULT g_stringDelimiter) RETURN JSONStructObj;
   PROCEDURE HTMLdumpJSONObj(p_obj IN OUT NOCOPY JSONStructObj);
   FUNCTION getAttrValue(p_obj JSONStructObj, pname VARCHAR2, pdecode BOOLEAN DEFAULT TRUE) RETURN VARCHAR2;
   FUNCTION setAttrSimpleValue(p_obj JSONStructObj, pname VARCHAR2, pvalue VARCHAR2, pformated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION setAttrSimpleValue(p_obj JSONStructObj, pname VARCHAR2, pbool BOOLEAN, pformated BOOLEAN DEFAULT FALSE) RETURN JSONStructObj;
   FUNCTION validateJSONObj(p_obj IN OUT NOCOPY JSONStructObj, pvalidate BOOLEAN DEFAULT FALSE) RETURN PLS_INTEGER;
   PROCEDURE print(p_str VARCHAR2);
   FUNCTION getVersion RETURN VARCHAR2;
   PROCEDURE test;

END PAW_JSON;
/

