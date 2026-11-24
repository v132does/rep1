CREATE OR REPLACE TYPE IT."TYP_RETORNOFACPOD"                                          FORCE IS OBJECT
(
accountNumber     varchar2(25),
name              varchar2(120),
segmentName       varchar2(35),
segmentCode       number,
executiveName     varchar2(120),
executiveCode     varchar2(20),
accountSigners    typ_accountSigners,
type              varchar2(1),
branch            number(1),
CONSTRUCTOR FUNCTION TYP_RETORNOFACPOD RETURN SELF AS RESULT
)
/

