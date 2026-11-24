CREATE OR REPLACE TRIGGER IT.TB_TA_PAG_SUE_EMP_TMP
BEFORE INSERT ON TA_PAG_SUE_EMP_TMP
FOR EACH ROW

DECLARE

  v_emp_cod_persona    ba_personas.cod_persona%type;  
  v_ruc_empresa        ba_personas.nro_documento%type;
  v_cod_ente           ge_entes.cod_ente%type;

BEGIN
-- Traer persona de la empresa
  Begin
   Select ruc_empresa
     into v_ruc_empresa
     from ta_pag_sue_ruc_tmp;
  Exception
    when no_data_found then
      v_ruc_empresa := null;
      --raise_application_error(-20010,'Error al traer la empresa. Verifique el proceso de importación de la empresa : '||' '||sqlerrm);       
  End;     
  If v_ruc_empresa is not  null then
  --Trer el codigo de persona de la empresa  
    Begin
      SELECT cod_persona
        into v_emp_cod_persona
        from ba_personas
       where nro_documento = v_ruc_empresa;
    Exception
      when others then
         raise_application_error(-20010,'Error al traer el codigo de persona de la empresa de RUC : '||v_ruc_empresa||' '||sqlerrm);
    End;
  -- Traer codigo de ente
    Begin
      SELECT cod_ente
        into v_cod_ente
        from ge_entes
       where cod_persona = v_emp_cod_persona
         and tipo = 'SU'
				 and rownum = 1;   --Pago de Sueldos
    Exception
      when others then
         raise_application_error(-20010,'Error al traer el codigo del Ente de la empresa de RUC : '||v_ruc_empresa||' '||sqlerrm);
    End;
  -- Actualizar empresa
   :new.cod_empresa := null;--v_cod_ente;
  End if;   
exception
   when others then
     if sqlcode < -20000  then
     	  raise;
     else
        raise_application_error(-20000,'TB_TA_PAG_SUE_EMP_TMP : Alta de Ruc de Empleados ' || sqlerrm);
     end if;
END;
/

