CREATE OR REPLACE PROCEDURE IT.PRA_TAR_DEB_REN_MASIVO(P_NRO_LOTE IN NUMBER) IS
  -- Procesa las RENOVACIONES Masivas de TD--
  -- Todas las TD enviadas en archivo--

  v_lugar           varchar2(100);
  v_fecha           date := pag_cal.FU_OBT_FEC_ACTUAL(3);
  v_fec_envio       date := to_date(to_char(Sysdate,'dd/mm/yyyy')||to_char(Sysdate,'hh24:mi:ss') , 'dd/mm/yyyy hh24:mi:ss');
  v_nue_emision     ah_tar_Debitos.nro_emision%type;
  v_nro_emision     ah_tar_Debitos.nro_emision%type;
  v_nue_adherente   ah_tar_Debitos.adherente%type;
  v_fec_vencimiento date;
  v_fec_ven_ant     date;
  v_cod_procesadora ah_tar_debitos.cod_ent_procesadora%type := fug_obt_pardinamico('COD_PRO_BANCARD');
  v_nro_bin_ant     ah_tar_debitos.nro_bin%type;
  v_renovacion      varchar2(1);
  v_tip_tar_deb_ant     ah_tar_Debitos.tip_tar_debito%type;
  v_tot_renovadas   number;
  v_cod_causa       ah_tar_debitos.cod_causa%type := '295';--DYDMR-7138--Se agrega cod_causal RENOVACION POR VENCIMIENTO para las renovac. de TDD para el envío de acción a Infonet.
  v_nro_cuenta      ah_tar_deb_masivo.nro_cuenta%type;
  v_tip_tarjeta     ah_tar_deb_masivo.tip_tarjeta%type;
  v_tip_pla_ant     ah_tar_deb_masivo.tip_tarjeta%type;
  v_adherente       ah_tar_deb_masivo.adherente%type;
  v_cod_persona     ah_tar_deb_masivo.cod_persona%type;
  v_ind_pro_registro varchar2(1);
  v_nro_tarjeta     ah_tar_debitos.nro_tarjeta%type;
  ---
  ----DYDMR-6822
  v_err_ctas varchar2(200); --acumulamos las ctas con error.
  v_msj_det_error varchar2(4000);
  v_msj_det_error_aux varchar2(4000);
  v_ret_carro varchar2(500) := '**';
  v_can_reg_lote number(6);
  v_can_reg_error number(6);
  v_est_lote varchar2(1);
  v_hora varchar2(8);
  v_est_registro varchar2(1);
  v_tip_tar_ren ah_tar_Debitos.tip_tar_debito%type;
  v_nro_bin_ren ah_tar_debitos.nro_bin%type;
  v_tip_proceso varchar2(1);
  v_con_registros number(6);
  v_des_accion ba_cod_referencias.abreviatura%type;

  --Cursores a TD a renovar--
  cursor c_tar_ren_masivo is
    select a.*, a.rowid registro
      from ah_tar_deb_masivo a
     where a.nro_lote = p_nro_lote
       and a.est_lote = 'P' --Lote Procesado--
       and a.est_registro = 'N' --Registro Normal, sin errores--
     order by a.nro_registro;

  --Cursor de las tarjetas a renovar
  Cursor c_tar_ren_datos is
  select t.nro_cuenta, t.adherente ,
         nvl(t.cod_ofi_origen,g.cod_oficina) cod_ofi_origen, t.embozado,
         fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora,
         c.cod_moneda, nro_bin, tip_tar_Debito, (select sum(t.mto_ingreso)
                                                  from CR_INF_LABORALES T
                                                 where T.ACTUAL = 'S'
                                                   --and T.MTO_FIJO = 'S'
                                                   and t.cod_persona = l.cod_persona) mto_ingreso, 
         c.cod_modalidad, t.nro_tarjeta
        -- fug_tie_mov_extranjero(c.nro_cuenta, c.cod_modalidad,-12) mov_ext
    from ah_Tar_debitos t, cc_cta_corrientes c, ge_cta_clientes g, ge_clientes l
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = c.nro_cuenta
     and g.cod_persona = l.cod_persona
     and t.cod_persona = g.cod_persona--Ajuste para que no duplique (Cuando tiene varios firmantes)
     and c.estado in('N','A','S')
     --and to_number(to_char(t.fec_vencimiento, 'yyyymm')) = to_number(p_ano||lpad(to_char(p_mes),2,'0'))
     and t.cod_est_solicitud not in(15,16,17) --15-Anulada p/enviar a Infonet / 16-Anulada. (No permite reimpresion TD) / 17-No utilización del Plástico
     and t.tar_Activa = 'S'
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) > ADD_MONTHS(t.fec_vencimiento, -4)
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) >  last_day(ADD_MONTHS(trunc(sysdate), -4))
     --información de ingreso
     ----
     and t.nro_cuenta = v_nro_cuenta
     --and t.tip_tar_debito = v_tip_tarjeta --Se debe convertir--
     and t.adherente = v_adherente
     and t.cod_persona = v_cod_persona
     --Fec_vencimiento va en el archivo--
     and t.nro_emision = (select max(k.nro_emision)
                            from ah_tar_debitos k
                           where k.nro_cuenta = t.nro_cuenta
                             and k.adherente = t.adherente
                             and k.cod_persona = t.cod_persona
                             and k.cod_est_solicitud not in(15,16,17))
   union
  select t.nro_cuenta , t.adherente,
         nvl(t.cod_ofi_origen,g.cod_oficina ), t.embozado,
         fec_vencimiento,
         t.fec_ingreso, t.cod_persona, t.nro_emision,
         g.cod_modulo , t.tip_envio,t.referencia, t.cod_ent_procesadora, v.cod_moneda, nro_bin,
         tip_tar_debito, (select sum(t.mto_ingreso)
                           from CR_INF_LABORALES T
                          where T.ACTUAL = 'S'
                            --and T.MTO_FIJO = 'S'
                            and t.cod_persona = l.cod_persona) mto_ingreso, 
         v.cod_modalidad, t.nro_tarjeta
         --fug_tie_mov_extranjero(v.nro_cuenta, v.cod_modalidad,-12) mov_ext
    from ah_tar_debitos t, ah_cta_vistas v , ge_cta_clientes g , ge_clientes l
   where t.nro_cuenta  = g.nro_cuenta
     and t.nro_cuenta  = v.nro_cuenta
     and g.cod_persona = l.cod_persona
     and t.cod_persona = g.cod_persona--Ajuste para que no duplique (Cuando tiene varios firmantes)
     and v.estado in('N','A','S')
     --and to_number(to_char(t.fec_vencimiento, 'yyyymm')) = to_number(p_ano||lpad(to_char(p_mes),2,'0'))
     and t.cod_est_solicitud not in(15,16,17) --15-Anulada p/enviar a Infonet / 16-Anulada. (No permite reimpresion TD) / 17-No utilización del Plástico
     and t.tar_Activa = 'S'
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) > ADD_MONTHS(t.fec_vencimiento, -4)
     --and greatest(nvl(trunc(fec_ult_mov_pos),to_date('01010001','ddmmyyyy')),nvl(trunc(fec_ult_mov_atm),to_date('01010001','ddmmyyyy'))) >  last_day(ADD_MONTHS(trunc(sysdate), -4))
     --información de ingreso
     ----
     and t.nro_cuenta = v_nro_cuenta
     --and t.tip_tar_debito = v_tip_tarjeta --Se debe convertir--
     and t.adherente = v_adherente
     and t.cod_persona = v_cod_persona
     and t.nro_emision = (select max(k.nro_emision)
                            from ah_tar_debitos k
                           where k.nro_cuenta = t.nro_cuenta
                             and k.adherente = t.adherente
                             and k.cod_persona = t.cod_persona
                             and k.cod_est_solicitud not in(15,16,17))
   order by 5,12,1;
BEGIN
  Begin PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1;end;

  -- Obtengo el nro de bin actual de la procesadora
  v_hora  := to_char(sysdate,'HH24:MI:SS');
  v_tot_renovadas := 0;

  --Tarjetas a Renovar--
  v_can_reg_error := 0;
  v_can_reg_lote  := 0;
  v_con_registros := 0;
  v_tip_proceso := null;
  v_des_accion := null;
  for det in c_tar_ren_masivo loop
      v_nro_cuenta := det.nro_cuenta;
      v_tip_tarjeta := det.tip_tarjeta;
      v_fec_vencimiento := det.fec_vencimiento;
      v_adherente := det.adherente;
      v_cod_persona := det.cod_persona;
      v_msj_det_error := null;
      v_msj_det_error_aux := null;
      v_can_reg_lote := nvl(v_can_reg_lote,0) + 1;
      v_est_registro := 'N';
      v_ind_pro_registro := 'N';
      v_con_registros := nvl(v_con_registros,0) + 1;
      v_nro_tarjeta := null;
      
      if v_con_registros = 1 then
         v_tip_proceso := det.tip_proceso;
         v_des_accion  := fue_obt_des_refcodes('TIP_ACC_TARDEB',
                          fue_obt_des_refcodes('TIP_PRO_MAS_TARDEB',v_tip_proceso));
      end if;

      --Asigna tipo de tarjeta y bin--
      v_tip_tar_ren := det.tip_tar_debito;
      v_nro_bin_ren := det.nro_bin;

      --Proeso Principal--
      v_lugar := 'Procesando '||v_des_accion;
      for reg in c_tar_ren_datos loop
          v_ind_pro_registro := 'S';
          v_fec_ven_ant := reg.fec_vencimiento;
          v_tip_tar_deb_ant := reg.tip_tar_debito;
          v_nro_bin_ant := reg.nro_bin;
          v_tip_pla_ant := fue_obt_des_refcodes('TIP_TAR_DEBITO',reg.tip_tar_debito);
          v_nro_emision := reg.nro_emision;
                    
          --- Si el nro. de bin es igual al bin actual de la procesadora entonces se toma como una renovacion
          v_msj_det_error_aux := null;
          if v_tip_proceso = 'R' then --Renovacion--
             if nvl(v_nro_bin_ant,0) = nvl(v_nro_bin_ren,0) then
                v_nue_adherente := reg.adherente;
                v_nue_emision   := lpad(to_char(to_number(reg.nro_emision)+1), 2, '0');
                v_renovacion      := 'S';
                v_nro_tarjeta := reg.nro_tarjeta;
             else
                --Error--
                v_msj_det_error_aux := 'Error. No coresponde a '||v_des_accion||' '||reg.nro_cuenta||'-'||reg.cod_persona||'-'||'Tipo:'||v_tip_tar_ren||'-'||v_nro_bin_ren||'-'||v_nue_adherente||'-'||v_nue_emision;
             end if;
          elsif v_tip_proceso = 'A' then --Alta--
             if nvl(v_nro_bin_ant,0) <> nvl(v_nro_bin_ren,0) then
                v_nue_adherente := det.adherente;--correccion --DYDMR-15288
                v_nue_emision   := '01';
                v_renovacion    := 'N';
             else
                --Error--
                v_msj_det_error_aux := 'Error. No coresponde a Alta '||reg.nro_cuenta||'-'||reg.cod_persona||'-'||'Tipo:'||v_tip_tar_ren||'-'||v_nro_bin_ren||'-'||v_nue_adherente||'-'||v_nue_emision;
             end if;
          end if;
          if v_msj_det_error_aux is not null then
              v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
          end if;
          if v_msj_det_error is null then
              v_fec_vencimiento := det.fec_vencimiento;
              --Control de fecha de venc, y tipo--
              v_msj_det_error_aux := null;
              if ((v_tip_tar_deb_ant = v_tip_tar_ren) and 
                  (v_fec_ven_ant = v_fec_vencimiento)) then
                 --Misma TD y Fec. Venc. anterior--
                 v_msj_det_error_aux := 'Error. Misma TD y Fec Venc para embozar '||reg.nro_cuenta||'-'||reg.cod_persona||'-'||
                     'Tipo:'||v_tip_tar_ren||'-'||
                     fue_obt_des_refcodes('TIP_TAR_DEBITO',v_tip_tar_ren)||'-'||
                     fue_obt_sig_refcodes('TIP_TAR_DEBITO',v_tip_tar_ren)||'-'||
                     'Bin:'||v_nro_bin_ren||'-'||'Adher.'||v_nue_adherente||'-'||'Emis.'||v_nue_emision||
                                       '-Venc.'||to_char(v_fec_vencimiento,'dd/mm/yyyy');
              end if;
              if v_msj_det_error_aux is not null then
                  v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
              end if;
              
              if v_msj_det_error is null then          
                 --Insertar en ah_Tar_debitos la renovacion
                 BEGIN
                 v_msj_det_error_aux := null;
                 insert into ah_tar_debitos
                 ( nro_cuenta,
                   tar_activa,
                   fec_ingreso,
                   cod_persona,
                   embozado,
                   cod_usuario,
                   fec_grabacion,
                   adherente,
                   nro_emision,
                   cod_est_solicitud,
                   cod_causa,
                   cod_ofi_origen,
                   fec_recepcion,
                   fec_entrega,
                   fec_ult_impresion,
                   fec_vencimiento,
                   fec_cancelacion,
                   nro_planilla,
                   tip_planilla,
                   motivo,
                   nro_pla_anterior,
                   fec_envio ,
                   tip_envio,
                   referencia,
                   cod_ent_procesadora, renovacion,nro_bin,
                   tip_tar_debito,
                   nro_lote, ide_reg_lote)
                 values (reg.nro_cuenta,
                         'S',
                         v_fecha,
                         reg.cod_persona,
                         reg.embozado,
                         user,
                         v_fecha,
                         v_nue_adherente,
                         v_nue_emision,
                         '2', -- A aprobar por el operativo
                         null,
                         reg.cod_ofi_origen,
                         null,
                         null,
                         reg.fec_ingreso,
                         v_fec_vencimiento,
                         null,
                         null,
                         null,
                         null,
                         null,
                         v_fec_envio,
                         reg.tip_envio,
                         reg.referencia,
                         v_cod_procesadora, v_renovacion, v_nro_bin_ren, v_tip_tar_ren,
                         det.nro_lote, det.ide_reg_lote);
                 v_tot_renovadas := v_tot_renovadas + 1 ;
                 EXCEPTION --DYDMR-6822
                   WHEN DUP_VAL_ON_INDEX THEN
                     v_err_ctas := v_err_ctas|| ' - '||reg.nro_cuenta;
                     v_msj_det_error_aux := 'Error duplicacion al insertar TD para '||v_des_accion||' '||reg.nro_cuenta||'-'||reg.cod_persona||'-'||'Tipo:'||v_tip_tar_ren||'-'||v_nro_bin_ren||'-'||v_nue_adherente||'-'||v_nue_emision;
                 END;
                 if v_msj_det_error_aux is not null then
                    v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
                 end if;
                   --
                   -- Al número de emisión anterior la cancela y le inserta la fecha de cancelacion
                   --
                   --v_lugar := 'Actualizando AH_TAR_DEBITOS RENOVADAS ...';
                 if v_msj_det_error is null then
                     v_msj_det_error_aux := null;
                     update AH_TAR_DEBITOS
                        set cod_est_solicitud = '16',
                            fec_cancelacion = trunc(v_fec_envio),
                            cod_causa = v_cod_causa --DYDMR-7138
                      where nro_cuenta  = reg.nro_cuenta
                        and cod_persona = reg.cod_persona
                        and adherente   = reg.adherente
                        and nro_emision = reg.nro_emision
                        and nvl(nro_bin,v_nro_bin_ren) = nvl(reg.nro_bin,v_nro_bin_ren)
                        and cod_ent_procesadora = v_cod_procesadora;
                     if SQL%NOTFOUND then --DYDMR-6822
                       v_err_ctas := v_err_ctas|| ' - '||reg.nro_cuenta;
                       v_msj_det_error_aux := 'Error al act. TD anterior '||reg.nro_cuenta||'-'||reg.adherente||'-'||reg.nro_emision;
                     end if;
                     if v_msj_det_error_aux is not null then
                        v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
                     end if;
                 end if;
              end if;
          end if;
      End Loop;
      v_msj_det_error_aux := null;
      if v_ind_pro_registro = 'N' then
         v_msj_det_error_aux := 'Error sin datos para '||v_des_accion||' TD '||det.nro_cuenta||'-'||det.cod_persona||'-'||det.adherente;
      end if;
      if v_msj_det_error_aux is not null then
         v_msj_det_error := substr(v_msj_det_error||v_msj_det_error_aux,1,4000);
      end if;
      if v_msj_det_error is not null then
         v_est_registro := 'E';
         v_can_reg_error := nvl(v_can_reg_error,0) + 1;
         v_msj_det_error := substr('Gen.Dat-Nro.Reg.:'||to_char(det.nro_registro)||v_ret_carro||v_msj_det_error,1,4000);
      end if;
      update ah_tar_deb_masivo y
         set y.est_registro = v_est_registro,
             y.msj_registro = v_msj_det_error,
             y.nro_emision = v_nro_emision,
             y.tip_tar_ant = v_tip_pla_ant,
             y.tip_tar_deb_ant = v_tip_tar_deb_ant,
             y.nro_bin_ant = v_nro_bin_ant,
             y.nro_tarjeta = v_nro_tarjeta,
             y.nue_adherente = v_nue_adherente,
             y.nue_nro_emision = v_nue_emision,
             y.fec_ven_ant = v_fec_ven_ant
       where y.rowid = det.registro;
  end loop;

  --Verificar el lote--
  if v_can_reg_error = v_can_reg_lote then
     v_est_lote := 'E';
  else
     v_est_lote := 'G';
  end if;
  --Actualizar Lote al final del Proceso--
  update ah_tar_deb_masivo y
     set y.est_lote = v_est_lote, --Procesado--
         y.fec_gen_lote = v_fecha,
         y.hor_gen_lote = v_hora
   where y.nro_lote = p_nro_lote;

  v_lugar := 'Insertando en AH_TAR_DEB_ENVIOS.';
  if v_tot_renovadas > 0 then
      begin
       insert into AH_TAR_DEB_ENVIOS(
                      FEC_PROCESO,
                      ESTADO,
                      CAN_TAR_RENOVADAS,
                      COD_ENT_PROCESADORA)
               values (v_fec_envio,
                       'G',
                       v_tot_renovadas,
                       v_cod_procesadora);
      Exception
        When Others then
          raise_application_error(20001,'ERROR AL INSERTAR AH_TAR_DEB_ENVIOS '||SQLERRM);
      end;
    end if;
exception
  when Others then
       raise_application_error(20001,'Error en PRA_TAR_DEB_REN_MASIVO: '||v_lugar||'-'||SQLERRM);
end PRA_TAR_DEB_REN_MASIVO;
/

