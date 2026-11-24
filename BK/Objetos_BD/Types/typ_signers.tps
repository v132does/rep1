CREATE OR REPLACE TYPE IT."TYP_SIGNERS"                                          FORCE IS OBJECT
(
clientNumber      number(5),
documentNumber    varchar2(200),
signerName        varchar2(200),
documentType      number(5),
Country           number(5),
signerType        varchar2(200),
ownershipName     varchar2(200),
ownershipCode     number(5),
personType        varchar2(1),
CONSTRUCTOR FUNCTION TYP_SIGNERS RETURN SELF AS RESULT
)
/

