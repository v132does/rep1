CREATE OR REPLACE TRIGGER IT.TB_AP_REQ_APROBACIONES
 BEFORE DELETE OR INSERT OR UPDATE
 ON AP_REQ_APROBACIONES
 FOR EACH ROW


DECLARE

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD;

/* Registrar campos de auditoria para insercion de datos. */
PROCEDURE LP_REG_AUD_INS
 IS
begin
   :new.fec_insercion := sysdate;
   :new.usu_insercion := substr(user,1,10);
end;
/* Registrar campos de auditoria para modificacion del registro. */
PROCEDURE LP_REG_AUD_MOD
 IS
begin
   :new.fec_modificacion := sysdate;
   :new.usu_modificacion := substr(user,1,10);
end;
Begin

Declare
   v_orden                  ap_gru_tip_req.orden%type;
   v_cod_grupo              ap_gru_tip_req.cod_grupo%type;
   v_cod_tip_requerimiento  ap_tip_requerimientos.cod_tip_requerimiento%type;
   v_cod_usuario            ap_requerimientos.cod_usuario%type;

Begin
    if inserting then
      -- Verificar si existen valores nulos
       if :new.cod_grupo is null
          or :new.estado is null then
          raise_application_error(-20000,
          'Codigo de Grupo o Estado nulo');
       end if;

    elsif updating then

      if :old.estado = 'P' and
         (:new.estado = 'A' or :new.estado = 'C') then

         if :new.cod_usuario is null then
            raise_application_error(-20000,
            'Usuario de aprobación no puede ser nulo');
         end if;
         if :new.fec_verificacion is null then
            raise_application_error(-20000,
            'Fecha de verficación no puede ser nula');
         end if;
      elsif deleting then
           if :old.estado = 'A' or :old.estado = 'C' then
                raise_application_error(-20001,
            'El Requerimiento contiene aprobaciones/cancelaciones');
           end if;
     end if;

    end if;
End;

End;
/

