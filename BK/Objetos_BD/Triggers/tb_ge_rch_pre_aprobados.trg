CREATE OR REPLACE TRIGGER IT.TB_GE_RCH_PRE_APROBADOS
 BEFORE INSERT
 ON GE_RCH_PRE_APROBADOS
 FOR EACH ROW
DECLARE
V_CODIGO NUMBER(18);

BEGIN

   if inserting  then
    /* BEGIN
       select nvl(max(a.codigo),0)
       into v_codigo
        from ge_rch_pre_aprobados a;
     EXCEPTION
       when no_data_found then
         v_codigo:=0;
     END;

     v_codigo:= nvl(v_codigo,0) +1;*/
	 --DYDMR 5756
     v_codigo:= s_cod_rch_preaprobado.NextVal;
     :new.codigo:=v_codigo;

   end if;
END;
/

