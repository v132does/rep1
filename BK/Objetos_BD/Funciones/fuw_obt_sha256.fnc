CREATE OR REPLACE FUNCTION IT.fuw_obt_sha256 (txt varchar2)

RETURN VARCHAR2

AS

LANGUAGE JAVA

NAME 'calculasha2.fncsha(java.lang.String) return String';
/

