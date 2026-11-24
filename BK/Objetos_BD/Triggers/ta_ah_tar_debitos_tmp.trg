CREATE OR REPLACE TRIGGER IT.TA_AH_TAR_DEBITOS_TMP
AFTER  INSERT ON AH_TAR_DEBITOS_TMP
FOR EACH ROW

DECLARE
  v_activa         varchar2(1);
  v_est_solicitud  ah_tar_debitos.cod_est_solicitud%type;
  v_existe         number;
  v_cod_oficina    ge_cuentas.cod_oficina%type;
  v_tip_tar_debito ah_tar_debitos.tip_tar_debito%type;
  v_tip_envio      ge_dir_envios.tip_envio%type;
  v_referencia     ge_dir_envios.referencia%type;
BEGIN
 If  substr(:new.nro_tarjeta,1,6) = '600691' then  --Bin viejo, no se procesa
    null;
 else    
    if  :new.estado = 1 then -- Activo
      v_activa := 'S';
    elsif :new.estado = 0 then -- bloqueado
      v_activa := 'N';
    end if;
    if  :new.estado = 1 then -- Activo
      if  :new.est_pin = 'A' then  -- Pin activo (Ya esta en poder del cliente)
         v_est_solicitud := 12; -- Entregado al cliente
      else
         v_est_solicitud := null; --Se pasa nulo para que mantenga el estado actual
      end if;      
    end if;  
   -- Verificar si existe el registro en AH_TAR_DEBITOS
   Select count(*) into v_existe 
     from ah_tar_Debitos
    where nro_cuenta  = :new.nro_cuenta
      and adherente   = :new.adherente
      and nro_emision = :new.nro_emision
      and nro_bin     = substr(:new.nro_tarjeta,1,6);
   /* Si no existe puede que se haya dado de alta en Infonet directamente, entonces dar
      de alta en IT  */     
   If  v_existe = 0    -- dar de alta en IT si tuvo algun movimiento    
   and (:new.fec_ult_mov_pos is not null
    or  :new.fec_ult_mov_atm is not null) then   
     --Traer la oficina de la cuenta 
     Begin
        Select cod_oficina into v_cod_oficina
          from ge_cuentas
         where nro_cuenta = :new.nro_cuenta;
     Exception
       when others then
         --raise_application_error(-20000,'Error al traer oficina de la cuenta ' || :new.nro_cuenta||' ' ||sqlerrm);      
         v_cod_oficina := null;          
     End;    
     If v_cod_oficina is not null then --- Si la cuenta no existe, no procesar el registro
     -- Traer el codigo del tipo de tarjeta de debito (tipo de embozado)
      Begin
        Select val_minimo into v_tip_tar_debito
          from ba_cod_referencias
         where abreviatura = :new.cod_embozado;
      Exception
        when others then
          v_tip_tar_debito := null;
      end;
      -- Traer la direccion de la cuenta
      Begin
         select tip_envio, referencia
           into v_tip_envio, v_referencia
           from ge_dir_envios
          where cod_persona = Fug_obt_cli_principal(:new.nro_cuenta)
            and nro_cuenta  = :new.nro_cuenta;
      Exception
        when no_data_found then
           Begin
            select tip_envio, referencia
              into v_tip_envio, v_referencia
              from ge_dir_envios
             where cod_persona = Fug_obt_cli_principal(:new.nro_cuenta)
               and nro_cuenta  is null;
           Exception
             when others then
               v_tip_envio := null;
               v_referencia := null;                  
           End;
        when others then
           v_tip_envio := null;
           v_referencia := null;            
       End;     
       if v_referencia is null then  --si no tiene direccion de envio se asigna Retener en la oficina de la cuenta
          v_tip_envio := 'R';
          v_referencia := v_cod_oficina;
       end if;                
      -- Inserta en tabla de tarjetas de debito
     Insert into ah_Tar_Debitos
     (nro_cuenta,tar_activa,fec_ingreso,cod_persona,
      embozado,cod_usuario,Fec_grabacion,
      adherente,nro_emision,cod_ofi_origen,fec_vencimiento,
      tip_envio,referencia,cod_est_solicitud,cod_ent_procesadora,
      tip_tar_debito,Nro_tarjeta,cod_est_pin,nro_bin,
      fec_ult_mov_pos,fec_ult_mov_atm)
     Values
     (:new.nro_cuenta,v_Activa,trunc(:new.fec_alta),Fug_obt_cli_principal(:new.nro_cuenta), 
      :new.embozado,user,sysdate,
      :new.adherente,:new.nro_emision,v_cod_oficina,last_day(to_date(:new.fec_vencimiento||'/01','rrrr/mm/dd')),
      v_tip_envio,v_referencia,nvl(v_est_solicitud,4),fug_obt_pardinamico('COD_PRO_BANCARD'),
      v_tip_tar_debito,:new.nro_tarjeta,:new.est_pin,substr(:new.nro_tarjeta,1,6),
      :new.fec_ult_mov_pos,:new.fec_ult_mov_atm);
     End if; 
   elsif v_Existe <> 0 then  -- ya existe   
     --Actualizar campos de la table AH_tAR_DEBITOS
     Update AH_TAR_DEBITOS
        set tar_activa = v_activa,
            cod_est_pin = :new.est_pin,
  --          cod_est_solicitud = nvl(v_est_solicitud,cod_est_solicitud),
            fec_ult_mov_pos = :new.fec_ult_mov_pos,
            fec_ult_mov_atm = :new.fec_ult_mov_atm,
            nro_tarjeta     = :new.nro_tarjeta
      where nro_cuenta = :new.nro_cuenta
        and adherente  = :new.adherente
        and nro_emision = :new.nro_emision
        and nro_bin     = substr(:new.nro_tarjeta,1,6);        
    end if;    
 End if;
EXCEPTION
   when others then
        raise_application_error(-20000,'Importacion Maestro de Tarjeta de Debito ' || sqlerrm);
END;
/

