CREATE OR REPLACE PROCEDURE IT.prt_ins_rec_apr_autorizaciones IS

  v_nom_programa      varchar2(50):='PRT_INS_REC_APR_AUTORIZACIONES';
  v_fec_actual        ge_calendarios.fec_actual%TYPE;
  v_nro_proceso       ta_con_tra_dia_cab_gp.nro_car_dia%type;
  v_exi_arc_fecha     varchar2(1);
  v_fec_pro_arc       ta_con_tra_dia_cab_gp.fec_proceso%type;
  v_lugar             varchar2(50);
  --
  v_can_registros     number;
  v_can_reg_tmp       ta_con_tra_dia_res_gp_tmp.can_registro%type;
  --
  r_log               ta_logs%ROWTYPE;

PROCEDURE lp_val_imp_archivo(p_nro_car_dia ta_con_tra_dia_cab_gp.nro_car_dia%type) IS
begin
    Begin
    pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1;
    end;
    --cabecera
    v_lugar:='Cabecera';
    begin
      insert into it.ta_con_tra_dia_cab_gp
      (nro_car_dia, tip_registro, cod_entidad, cod_id_archivo, des_archivo, fec_proceso, filler)
      (select p_nro_car_dia, tip_registro, cod_entidad, cod_id_archivo, des_archivo, to_char(to_date(fec_proceso, 'yyyymmdd'), 'dd/mm/yyyy'),
       filler from it.ta_con_tra_dia_cab_gp_tmp);  
    end;
    --resumen
    v_lugar:='Resumen';
    begin
      insert into it.ta_con_tra_dia_res_gp
      (nro_car_dia, tip_registro, fec_archivo, can_sol_anu, can_sol_apr, can_sol_rec, can_registro, filter)
      (select p_nro_car_dia, tip_registro, fec_archivo, can_sol_anu, can_sol_apr, can_sol_rec, can_registro, filter from it.ta_con_tra_dia_res_gp_tmp);
    end;
    --detalle
    v_lugar:='Detalle';
    begin
      insert into it.ta_con_tra_dia_det_gp
        (nro_car_dia,
         tip_registro,
         nro_cuenta,
         adicional,
         nro_tarjeta,
         fec_hora,
         fec_operacion,
         hor_operacion,
         importe,
         tip_moneda,
         aut_moneda,
         plan,
         cuotas,
         cod_autorizacion,
         aut_forzada,
         aut_rev_flag,
         aut_aut_debi,
         nro_comercio,
         nom_comercio,
         estado,
         relacionada,
         origen,
         rechazo,
         ica,
         mcc,
         tcc,
         cod_reg_fraude,
         des_reg_fraude,
         mod_entrada,
         terminal,
         usuario,
         standin,
         aut_mon_ori_so,
         imp_ori_autorizacion,
         imp_aut_convertido,
         sig_imp_aut_con,
         tot_imp_cargos,
         sig_imp_cargos,
         tot_imp_iva,
         sig_imp_iva,
         tot_imp_car_con,
         sig_car_convertido,
         tot_imp_iva_con,
         sig_iva_car_con,
         con_cargo,
         imp_car_1,
         sig_imp_car_1,
         imp_car_iva_1,
         con_car_2,
         imp_car_2,
         sig_imp_2,
         imp_iva_car_2,
         con_car_3,
         imp_car_3,
         sig_imp_3,
         imp_iva_car_3,
         imp_rg4240,
         sig_imp_rg4240,
         imp_iibb_rg4240,
         sig_imp_iibb_rg4240,
         pro_iibb_rg4240,
         mto_imp_ley_pais,
         sig_imp_ley_pais,
         filtro,
         cta_externa,
         request_id,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion,
         procesado,
         error,
         fec_proceso,
         cod_estado,
         fec_estado,
         imp_rg4815,
         sig_imp_rg4815,
         tra_tokenizada,
         ori_transaccion,
         aut_id,
         ext_cash,
         imp_ext_cash,
         sig_ext_cash,
         imp_rg_5272,
         sig_imp_rg_5272,
         fec_transferencia,
         cod_ins_adquieriente,
         nro_ref_recuperacion,
         id_terminal,
         nom_terminal,
         dat_token,
         dat_red,
         dat_billetera,
         per_env_fondos,
         cod_tip_producto)
        (select p_nro_car_dia,
                tip_registro,
                nro_cuenta,
                adicional,
                nro_tarjeta,
                fec_hora,
                to_date(substr(fec_hora,1,8),'dd/mm/yyyy') fec_operacion,
                to_char(to_date(substr(fec_hora,9,6),'hh24:mi:ss'),'HH24:MI:SS') hor_operacion,
                decode(i.tip_moneda, '2', i.importe, trunc(i.importe)) importe,
                tip_moneda,
                aut_moneda,
                plan,
                cuotas,
                cod_autorizacion,
                aut_forzada,
                aut_rev_flag,
                aut_aut_debi,
                nro_comercio,
                nom_comercio,
                estado,
                relacionada,
                origen,
                rechazo,
                ica,
                mcc,
                tcc,
                cod_reg_fraude,
                des_reg_fraude,
                mod_entrada,
                terminal,
                usuario,
                standin,
                aut_mon_ori_so,
                imp_ori_autorizacion,
                imp_aut_convertido,
                sig_imp_aut_con,
                tot_imp_cargos,
                sig_imp_cargos,
                tot_imp_iva,
                sig_imp_iva,
                tot_imp_car_con,
                sig_car_convertido,
                tot_imp_iva_con,
                sig_iva_car_con,
                con_cargo,
                imp_car_1,
                sig_imp_car_1,
                imp_car_iva_1,
                con_car_2,
                imp_car_2,
                sig_imp_2,
                imp_iva_car_2,
                con_car_3,
                imp_car_3,
                sig_imp_3,
                imp_iva_car_3,
                imp_rg4240,
                sig_imp_rg4240,
                imp_iibb_rg4240,
                sig_imp_iibb_rg4240,
                pro_iibb_rg4240,
                mto_imp_ley_pais,
                sig_imp_ley_pais,
                filtro,
                cta_externa,
                request_id,
                user,
                sysdate,
                user,
                sysdate,
                'N',
                decode(
                  (select distinct '1'
                  from ge_cta_clientes s
                  where s.relacion = 'P'
                  and s.nro_cuenta=i.nro_cuenta),'1',null,'Cuenta inválida'),
                trunc(sysdate),
                cod_estado,
                fec_estado,
                imp_rg4815,
                sig_imp_rg4815,
                tra_tokenizada,
                ori_transaccion,
                aut_id,
                ext_cash,
                imp_ext_cash,
                sig_ext_cash,
                imp_rg_5272,
                sig_imp_rg_5272,
                fec_transferencia,
                cod_ins_adquieriente,
                nro_ref_recuperacion,
                id_terminal,
                nom_terminal,
                dat_token,
                dat_red,
                dat_billetera,
                per_env_fondos,
                cod_tip_producto
           from it.ta_con_tra_dia_det_gp_tmp i);
    end;
exception
  when others then
    r_log.men_error:='Error en la importacion de registros.Lugar:'||v_lugar;
    r_log.nro_error:='-20000';
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || '-'||r_log.men_error||'- '||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,r_log.comentario);
end;


BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  v_fec_actual := pag_cal.fu_obt_fec_actual(5);

  r_log.nom_proceso := v_nom_programa;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Inicio proceso de archivo T7001D - Autorizaciones Apr/Rch ***';
  pat_igp.pr_ins_log(r_log, FALSE);
 
  begin
    select to_char(to_date(a.fec_proceso,'yyyy/mm/dd'),'dd/mm/yyyy')
      into v_fec_pro_arc
      from it.ta_con_tra_dia_cab_gp_tmp a;
  exception
    when others THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'al buscar la cabecera del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000, 'Error al buscar la cabecera del archivo. '||sqlerrm);
  end;

  begin
    select distinct 'S'
      into v_exi_arc_fecha
      from it.ta_con_tra_dia_cab_gp t
     where t.fec_proceso = v_fec_pro_arc;
  exception
    when others then
      v_exi_arc_fecha := 'N';
  end;

  if nvl(v_exi_arc_fecha, 'N')= 'S' THEN
    r_log.men_error:='El archivo T7001D ya fue conciliado.';
    r_log.nro_error:='-20000';
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'El archivo T7001D de fecha'||
                            v_fec_pro_arc || ' ya fue conciliado.- ' ||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000,'El archivo T7001D ya fue conciliado. '||sqlerrm);
  end if;

  begin
    select count(*)
      into v_can_reg_tmp
      from it.ta_con_tra_dia_det_gp_tmp;
  exception
    when others then
      v_can_reg_tmp := 0;
  end;

  begin
    select c.can_registro
      into v_can_registros
      from it.ta_con_tra_dia_res_gp_tmp c;
  exception
    when others THEN
      r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Error al buscar el resumen del archivo'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
      pat_igp.pr_ins_log(r_log);
      raise_application_error(-20000,'Error al buscar el resumen del archivo. '||sqlerrm);
  end;

  if nvl(v_can_registros, 0) <> nvl(v_can_reg_tmp, 0) THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - '||'Cantidad de Detalle no coincide con el resumen'||' - '||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
    pat_igp.pr_ins_log(r_log);
    raise_application_error(-20000, 'Cantidad de Detalle no coincide con el resumen.');
  end if;

  BEGIN
    select it.s_nro_car_dia_apr_rec_gp.nextval
      into v_nro_proceso
      from dual;
  EXCEPTION
    WHEN OTHERS THEN
      raise_application_error(-20000, 'Error al obtener el nro. de secuencia. ' || sqlerrm);
  END;

  --se importa el archivo
  lp_val_imp_archivo(v_nro_proceso);
  commit;
  r_log.fec_hor_ini := SYSDATE;
  r_log.comentario  := '*** Finaliza proceso de archivo T7001D - Autorizaciones Apr/Rch ***';
  pat_igp.pr_ins_log(r_log, FALSE);
EXCEPTION
  WHEN OTHERS THEN
    r_log.comentario := substr('Error en proceso : ' || r_log.nom_proceso || ' - Fec actual'||
                            to_char(v_fec_actual, 'dd/mm/yyyy') || ' - ' ||
                            sqlerrm,1,499);
    r_log.men_error:='Error en proceso : '||r_log.nom_proceso;
    pat_igp.pr_ins_log(r_log);
    prg_ins_log_programas(v_nom_programa,substr(sqlerrm,1,4000));
END;
/
