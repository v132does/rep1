CREATE OR REPLACE TRIGGER IT.TB_PR_CTA_PRE_CAN_RES4
 BEFORE DELETE OR INSERT OR UPDATE
 ON PR_CTA_PRE_CAN_RES4
 FOR EACH ROW
declare
 v_nro_secuencia number(20);
begin
   if inserting then
     SELECT s_nro_sec_re4.nextval INTO v_nro_secuencia FROM dual;
     :new.nro_secuencia:=  v_nro_secuencia;
   end if;
end;
/

