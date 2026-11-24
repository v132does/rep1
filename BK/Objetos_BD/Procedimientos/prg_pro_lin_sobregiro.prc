CREATE OR REPLACE PROCEDURE IT.PRG_PRO_LIN_SOBREGIRO is

Begin
    PAG_NOM.PR_PRO_LIN_SOBREGIRO(null, null, 'M') ;
exception
   when others then
       raise_application_error(-20001,'PRG_PRO_LIN_SOBREGIRO-'||sqlerrm);
end;
/

