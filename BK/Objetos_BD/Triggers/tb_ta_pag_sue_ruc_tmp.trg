CREATE OR REPLACE TRIGGER IT.TB_TA_PAG_SUE_RUC_TMP
BEFORE  INSERT ON TA_PAG_SUE_RUC_TMP
FOR EACH ROW

DECLARE
 v_cod_persona  ba_personas.cod_persona%type;
 v_cod_ente     ge_entes.cod_ente%type;
 v_nro_documento ba_personas.nro_documento%type;

BEGIN

-- Traer persona de la empresa
If :new.ruc_empresa is not null then
  Begin
    SELECT cod_persona
      into v_cod_persona
      from ba_personas
     where nro_documento = :new.ruc_empresa;
  Exception
    when no_data_found then
       If length(:new.ruc_empresa) < 10 then -- es persona fisica con cedula de identidad
         v_nro_documento := substr(:new.ruc_empresa,1, instr(:new.ruc_empresa,'-')-1);
         Begin
          Select cod_persona
            into v_cod_persona
            from ba_personas
           where nro_documento = v_nro_documento;
         Exception
          when others then
           raise_application_error(-20010,'Error al traer el codigo de persona de la empresa de RUC : '||substr(:new.ruc_empresa,1,8)||'-'||substr(:new.ruc_empresa,9,1)||' '||sqlerrm);
         End;
       End if;
    when others then
      raise_application_error(-20010,'Error al traer el codigo de persona de la empresa de RUC : '||substr(:new.ruc_empresa,1,8)||'-'||substr(:new.ruc_empresa,9,1)||' '||sqlerrm);
  End;
-- Traer codigo de ente
  Begin
    SELECT cod_ente
      into v_cod_ente
      from ge_entes
     where cod_persona = v_cod_persona
       and tipo = 'SU'
       and rownum = 1;   -- Pago de Sueldos
  Exception
    when others then
       raise_application_error(-20010,'Error al traer el codigo del Ente de la persona : '||v_cod_persona||' de la empresa de RUC : '||:NEW.ruc_empresa||' '||sqlerrm);
  End;
end if;
--
if  v_nro_documento is not null then
  :new.ruc_empresa := v_nro_documento;
end if;
exception
   when others then
     if sqlcode < -20000  then
         raise;
     else
        raise_application_error(-20000,'Alta de Ruc de Empresa ' || sqlerrm);
     end if;
END;
/

