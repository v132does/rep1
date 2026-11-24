CREATE OR REPLACE TRIGGER IT.TA_BW_OPE_CLAVES
  after update on bw_ope_claves
  for each row
declare
  v_tip_clave   varchar2(20);
  v_retorno NUMBER;
  v_direccion varchar2(200);
  v_db_name  VARCHAR2(20);
  v_terminal VARCHAR2(20);
  v_ret number;
begin 
  -- BSEVOCORE-374: Validar el envio de notificaciones en caso de que la base sea de producción y el esté habilitado para enviar
  SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
    INTO v_db_name, v_terminal
  FROM dual;
       
 IF (v_db_name = 'BBVA')  then  
    if updating then 
       if (:old.clave <> :new.clave and :new.est_clave = 'M') then
          v_direccion := substr(paw_not.fu_obt_cli_des_activo(:new.cod_persona), 1, 200);

          IF paw_not.fu_obt_suscripcion(:new.cod_persona) = 'N' OR v_direccion IS NULL THEN
             v_ret := paw_not.fu_alt_notificacion(:new.cod_persona, v_direccion);
          END IF;
                  
          v_retorno := paw_not.fu_not_cam_cla(:new.cod_persona, :new.cod_per_vinculada,  'C', :new.tip_clave);
        end if;

        if (:new.est_clave = 'B' and :new.est_clave <> :old.est_clave) then
          v_direccion := substr(paw_not.fu_obt_cli_des_activo(:new.cod_persona), 1, 200);

          IF paw_not.fu_obt_suscripcion(:new.cod_persona) = 'N' OR v_direccion IS NULL THEN
             v_ret := paw_not.fu_alt_notificacion(:new.cod_persona, v_direccion);
          END IF;

          v_retorno := paw_not.fu_not_cam_cla(:new.cod_persona, :new.cod_per_vinculada, 'B', :new.tip_clave);
        end if;
      end if;     
 END IF;
end TA_BW_OPE_CLAVES;
/

