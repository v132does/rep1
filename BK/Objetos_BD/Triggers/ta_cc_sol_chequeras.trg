CREATE OR REPLACE TRIGGER IT.TA_CC_SOL_CHEQUERAS
 AFTER DELETE OR INSERT OR UPDATE
 ON CC_SOL_CHEQUERAS
 FOR EACH ROW



DECLARE
vr_csche        cc_chequeras%rowtype; -- Registro de la tabla CC_CHEQUERAS
v_cod_modulo    ba_modulos.cod_modulo%type;
v_cod_modalidad ge_modalidades.cod_modalidad%type;
v_cod_oficina   ba_oficinas.cod_oficina%type;
v_cod_moneda    ba_monedas.cod_moneda%type;
v_serie         cc_chequeras.serie%type;
v_fcdehoy       date;
v_nro_che_inicial  cc_par_chequeras.sig_nro_cheque%type;
v_nro_che_final    cc_par_chequeras.sig_nro_cheque%type;
v_cantidad         cc_sol_chequeras.cantidad%type;
v_can_hojas        cc_sol_chequeras.cantidad%type;
v_bandera          BOOLEAN := FALSE;
-- Envio de mail al verificador
PROCEDURE LP_ENV_MAIL
  IS
  v_cod_persona         varchar2(10);
  v_dir_correo          varchar2(400) := null;
  cursor ver_chequeras is
   select distinct usa.dir_correo dir_correo
     from ba_rol_programas rpr, ba_usu_roles url, ba_usuarios usa
    where rpr.cod_programa = 'CMSOLCHB'
      and rpr.cod_rol = url.cod_rol
      and url.cod_usuario = usa.cod_usuario
      and usa.ver_cta_empleados = 'S'
      and usa.cod_usuario <> 'IT' -- no tomar IT
      and rpr.actualiza = 'S'; -- que pueda actualizar en el programa
--    order by fue_ver_sesion(usa.cod_usuario),
--             decode(usa.cod_usuario,'NOV','A',usa.cod_usuario);
BEGIN

  begin
     select cod_modalidad
       into v_cod_modalidad
       from ge_cuentas
      where nro_cuenta = :new.nro_cuenta;
     -- si es interna la cuenta
     if v_cod_modalidad <> 41 then
        for ch in ver_chequeras loop
          if ch.dir_correo is not null then
             if v_dir_correo is null then
                v_dir_correo := ch.dir_correo;
             else
                v_dir_correo := v_dir_correo||';'||ch.dir_correo;
             end if;
          end if;
        end loop;
        --- Enviar mail al verificador
        if v_dir_correo is not null then
          it_mail.mail(fug_obt_dir_correo,
                       v_dir_correo,
                       'Solicitud de Verificacion',
                       'El usuario '||USER||' solicita la Verificación de las Chequeras de la Cuenta '||:new.nro_cuenta||'.');
        end if;
     end if;
  exception
     when others then
         v_cod_modalidad := null;
  end;

END;
---
BEGIN
  
   -- 27-08-2013/RABP-PCC: VERIFICAMOS EL ESTADO NUEVO DE LA SOLICITUD PARA INSERTAR O NO EN CC_CHEQUERAS --
   if inserting then
     if :new.estado = 'V' then
        v_bandera := TRUE;
     else
       -- envia mail al verificador cuando la cuenta es interna --
        lp_env_mail;
     end if;
   end if;

   if updating or v_bandera=TRUE then
      --- Si se cambia el estado y el nuevo es Verificado Generar chequera (cc_chequeras -
      --- pac_che.pr_ins_cc_chequeras), recuperar para actualizar siguiente nro de cheque de cc_par_chequeras
      --- (pac_che.pr_obt_sig_nro_che) y actualizar el mismo inmediatamente
      if ((:old.estado <> :new.estado) and :new.estado = 'V') or v_bandera=TRUE then
          select cod_modulo, cod_modalidad, cod_oficina, cod_moneda
          into v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda
          from ge_cuentas
          where nro_cuenta = :new.nro_cuenta;
          --La cantidad de hojas es el resultado de los Talonarios * Cantidad de Hojas
          --v_cantidad := :new.cantidad * :new.can_hojas;
          --pac_che.pr_obt_sig_nro_che(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, :new.cod_tip_chequera,v_cantidad, v_nro_che_inicial,v_nro_che_final, v_serie);
          v_fcdehoy := pag_cal.fu_obt_fec_actual(v_cod_modulo);
          If :new.can_hojas <= 1000 then
            for i in 1..:new.cantidad loop
              pac_che.pr_obt_sig_nro_che(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, :new.cod_tip_chequera,:new.can_hojas, v_nro_che_inicial,v_nro_che_final, v_serie);
              vr_csche.nro_cuenta       := :new.nro_cuenta;
              vr_csche.serie            := v_serie;
              vr_csche.nro_che_inicial  := v_nro_che_inicial;
              vr_csche.nro_che_final    := v_nro_che_final;
              --vr_csche.can_cheques      := v_cantidad;
              vr_csche.can_cheques      := :new.can_hojas;
              vr_csche.estado           := 'S';--Solicitado, Impresa, Entregado, eN impresion
              vr_csche.fec_cam_estado   := v_fcdehoy;
              vr_csche.ult_che_emitido  := null;
              vr_csche.tipo             := :new.cod_tip_chequera;
              vr_csche.fec_solicitud    := :new.fecha;
              vr_csche.hor_solicitud    := :new.hora;
              vr_csche.cod_usuario      := :new.cod_usuario;
              vr_csche.cod_ofi_retiro   := :new.cod_ofi_retiro;
              vr_csche.cod_gru_envio    := null;
              --Insertar la chequera
              pac_che.pr_ins_cc_chequera(vr_csche);
            end loop;
          else
            v_cantidad  := ceil(:new.can_hojas/1000);
            v_can_hojas := 1000;
            for i in 1..v_cantidad loop
              If i = v_cantidad then
                v_can_hojas := :new.can_hojas - (1000 * (i-1));
              End if;
              pac_che.pr_obt_sig_nro_che(v_cod_modulo, v_cod_modalidad, v_cod_oficina, v_cod_moneda, :new.cod_tip_chequera,v_can_hojas, v_nro_che_inicial,v_nro_che_final, v_serie);
              vr_csche.nro_cuenta       := :new.nro_cuenta;
              vr_csche.serie            := v_serie;
              vr_csche.nro_che_inicial  := v_nro_che_inicial;
              vr_csche.nro_che_final    := v_nro_che_final;
              vr_csche.can_cheques      := v_can_hojas;
              vr_csche.estado           := 'S';--Solicitado, Impresa, Entregado, eN impresion
              vr_csche.fec_cam_estado   := v_fcdehoy;
              vr_csche.ult_che_emitido  := null;
              vr_csche.tipo             := :new.cod_tip_chequera;
              vr_csche.fec_solicitud    := :new.fecha;
              vr_csche.hor_solicitud    := :new.hora;
              vr_csche.cod_usuario      := :new.cod_usuario;
              vr_csche.cod_ofi_retiro   := :new.cod_ofi_retiro;
              vr_csche.cod_gru_envio    := null;
              --Insertar la chequera
              pac_che.pr_ins_cc_chequera(vr_csche);
            end loop;
          End if;
      end if;
   end if;
END;
/

