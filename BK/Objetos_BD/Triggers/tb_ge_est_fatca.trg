CREATE OR REPLACE TRIGGER IT.TB_GE_EST_FATCA
 BEFORE DELETE OR INSERT OR UPDATE
 ON GE_EST_FATCA
 FOR EACH ROW
DECLARE

BEGIN
   if inserting or updating then
    
      if  :new.plz_vencimiento is not null and :new.est_exp_vencimiento is null then
         raise_application_error(-20000,'Error. Debe definir Estado de Expiración de Vencimiento. '||sqlerrm);
      end if;
      if  :new.plz_caducidad is not null and :new.est_exp_caducidad is null then
         raise_application_error(-20000,'Error. Debe definir Estado de Expiración de Caducidad. '||sqlerrm);
      end if; 
      
   end if;

END;
/

