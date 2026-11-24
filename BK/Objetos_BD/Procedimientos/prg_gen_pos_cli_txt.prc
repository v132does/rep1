CREATE OR REPLACE PROCEDURE IT.PRG_GEN_POS_CLI_TXT
 IS
  BAND               number;
  v_fecha            date := pae_cnf.fu_obt_fec_actual(1);
  v_texto            clob;
  v_env_mail_gestor  varchar2(200) := fug_obt_pardinamico('ENV_MAIL_GES_POS_CLI');
  v_tex_notificacion varchar2(4000) := fug_obt_pardinamico('TEX_NOT_GESTOR');
  v_dir_destino      varchar2(200);
  v_tex_mail         varchar2(4000);
  v_dir_correo       ba_personas.dir_correo%type := fug_obt_dir_correo;
  v_dir_correo_ofi   ba_personas.dir_correo%type;
  v_ren_temporal     varchar2(20);
  v_cod_campanas     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_CAM_REN_LIN_SOB');
  v_cod_rub_eco_ren  ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_RUB_ECO_REN_LIN_SOB');
  v_motivo           varchar(2000);
  v_hor_iniff        varchar2(8);
  v_hor_finff        varchar2(8);
  v_hor_ini          varchar2(8);
  v_hor_fin          varchar2(8);

  cursor cabecera is
    select cod_usu_oficial, nom_oficial
      from ge_pos_clientes_det
     where fecha = v_fecha
       and nom_oficial is not null
     group by cod_usu_oficial, nom_oficial;

  cursor detalle_01(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           nro_cuenta,
           cod_moneda,
           can_dias,
           can_dias_sobregiro,
           nro_lin_sob_permanente,
           to_char(nvl(mto_lin_permanente, 0), '999G999G999G999') mto_lin_permanente,

           to_char(fec_vto_lin_permanente, 'dd/mm/yyyy') fec_vto_lin_permanente,
            to_char(nvl(mto_lin_temporal, 0), '999G999G999G999') mto_lin_temporal,
           nro_lin_sob_temporal,
           to_char(fec_vto_lin_temporal, 'dd/mm/yyyy') fec_vto_lin_temporal,
            to_char(nvl(saldo, 0), '999G999G999G999') saldo



      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '1';

  cursor detalle_02(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           nro_cuenta,
           cod_moneda,
           telefono,
           tipo,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           estado,
           cuota,
           to_char(fec_ven_cuota, 'dd/mm/yyyy') fec_ven_cuota,
           dia_mora,
            to_char(nvl(sal_cap_cuota, 0), '999G999G999G999') sal_cap_cuota,

            to_char(nvl(sal_cap_operacion, 0), '999G999G999G999') sal_cap_operacion
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '2'
       order by dia_mora desc;

  cursor detalle_03(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           nro_cuenta,
           cod_moneda,
           telefono,
           tipo,
            to_char(nvl(saldo, 0), '999G999G999G999') saldo,
            to_char(nvl(sal_mon_local, 0), '999G999G999G999') sal_mon_local
      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '3';

  cursor detalle_04(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nro_cuenta,
           nom_completo,
           descripcion,
           tip_valor,
           tipo,
           to_char(fec_vigencia, 'dd/mm/yyyy') fec_vigencia,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           val_tasa,
           val_extension
      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '4';

  cursor detalle_05(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           telefono,
           nro_cuenta,
           tipo,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           estado,
           cod_moneda,
           cuota,
           to_char(nvl(sal_cap_operacion, 0), '999G999G999G999')
           sal_cap_operacion,
           to_char(fec_ren_tas_orig, 'dd/mm/yyyy') fec_ren_tas_orig,
           tas_actual
      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '5';

  cursor detalle_06(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           telefono,
           nro_cuenta,
           tipo,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           estado,
           cod_moneda,
           to_char(nvl(capital, 0), '999G999G999G999')
           capital,
           to_char(nvl(sal_int_vencido, 0), '999G999G999G999')
           sal_int_vencido,
           to_char(nvl(sal_cap_operacion, 0), '999G999G999G999')
           sal_cap_operacion,
           monto -- DYDMR-3870 saldo bloqueado
      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '6';

  cursor detalle_07(v_usu_oficial varchar2) is
    select cod_Reporte,
           cod_persona,
           nom_completo,
           telefono,
           nro_cuenta,
           tipo,
           dia_mora,
           cod_moneda,
           to_char(nvl(saldo, 0), '999G999G999G999')
           saldo,
           to_char(nvl(lin_credito, 0), '999G999G999G999')
           lin_credito
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '7'
       order by dia_mora desc;

  cursor detalle_08(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           telefono,
           nro_cuenta,
           tipo,
           cod_tra_padre,
           des_tra_padre,
           cod_transaccion,
           des_transaccion,
           nro_documento,
           cod_moneda,
           to_char(nvl(monto, 0), '999G999G999G999')
           monto
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '8';

  cursor detalle_09(v_usu_oficial varchar2) is
    select cod_reporte,
           estado,
           cod_persona,
           nom_completo,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           nro_cuenta,
           cod_moneda,
           to_char(nvl(saldo, 0), '999G999G999G999')
           saldo,
           cod_oficina,
           cod_modalidad,
           des_modalidad
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '09';

  cursor detalle_10(v_usu_oficial varchar2) is
    select cod_Reporte,
           cod_persona,
           nro_garantia,
           tipo,
           estado,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           cod_moneda,
           valor,
           to_char(nvl(mto_aplicado, 0), '999G999G999G999')
           mto_aplicado
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '10';

  cursor detalle_11(v_usu_oficial varchar2) is
    select cod_reporte,
           nro_linea,
           cod_persona,
           nom_completo,
           to_char(Fec_otorgamiento, 'dd/mm/yyyy') fec_otorgamiento,
           to_char(fec_vencimiento, 'dd/mm/yyyy') fec_vencimiento,
           niv_aprobacion,
           cod_moneda,
           to_char(nvl(monto, 0), '999G999G999G999')
           monto
      from ge_pos_clientes_det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '11';

  cursor detalle_12(v_usu_oficial varchar2) is
    select cod_reporte,
           cod_persona,
           nom_completo,
           to_char(fec_nacimiento, 'dd/mm/yyyy') fec_nacimiento
      from ge_pos_clientes_Det
     where fecha = v_fecha
       and cod_usu_oficial = v_usu_oficial
       and cod_reporte = '12';

  procedure lp_logeo(p_cod_proceso varchar2, p_hor_ini varchar2, p_hor_fin varchar2)
  is pragma autonomous_transaction;
  begin
    insert into ge_log_procesos(fecha,cod_programa,cod_proceso,hor_inicio,hor_fin)
    values(pag_cal.FU_OBT_FEC_ACTUAL(1),'PRG_GEN_POS_CLI_TXT',p_cod_proceso, p_hor_ini, p_hor_fin);
    commit;
  exception
    when others then null;
  end;

begin
  delete ge_log_procesos where cod_programa = 'PRG_GEN_POS_CLI_TXT';
  
  BEGIN dbms_stats.gather_table_stats('IT','GE_POS_CLIENTES_DET'); END;
  
  v_dir_correo := fug_obt_dir_correo;
  v_hor_iniff := to_char(sysdate,'hh24:mi:ss');

  for C in cabecera loop
    v_dir_correo_ofi := fug_obt_dir_mail_usu(c.cod_usu_oficial);
    if v_dir_correo_ofi is not null then
      v_texto := null;
      v_texto := v_texto || 'Posición de Clientes por Gestor: ' ||
                 c.Cod_usu_oficial || ' ' || c.nom_oficial || CHR(13) ||
                 chr(10);
      BAND    := 0;
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for k in detalle_01(c.cod_usu_oficial) loop
        if BAND = 0 then
          BAND    := 1;
          v_texto := v_texto || k.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          k.cod_reporte) || chr(13) ||
                     chr(10);
          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nombre_Completo', 40, ' ') || chr(9) ||
                     lpad('Nro_Cuenta', 15, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) ||
                     lpad('Can_Dias', 8, ' ') || chr(9) || 'Dias_sobregiro' ||
                     chr(9) || lpad('Mto_lin_permanente', 20, ' ') || chr(9) ||
                     lpad('Vto_lin_permanente', 18, ' ') || chr(9) ||
                     lpad('Mto_lin_temporal', 20, ' ') || chr(9) ||
                     lpad('Vto_lin_temporal', 16, ' ') || chr(9) ||
                     lpad('Renov. Temporal', 20, ' ') || chr(9) ||
                     lpad('Motivo', 60, ' ') || chr(9) ||
                     lpad('Saldo', 20, ' ') || chr(13) || chr(10);
        end if;

        if k.nro_lin_sob_temporal is null then
           v_ren_temporal := null;
           v_motivo := null;
        else
          begin
            select decode(val_parametro, 'N', 'NO RENOVAR AUT.')
              into v_ren_temporal
              from ba_tab_dat_adicionales t
             where t.tab_relacion = 'CC_LIN_SOBREGIROS'
               and t.referencia = k.nro_lin_sob_temporal
               and t.parametro = 'RENOVAR';
          exception
            when others then
              v_ren_temporal := null;
          end;
          if v_ren_temporal is not null then
             begin
                select val_parametro
                  into v_motivo
                  from ba_tab_dat_adicionales t
                 where t.tab_relacion = 'CC_LIN_SOBREGIROS'
                   and t.referencia = k.nro_lin_sob_temporal
                   and t.parametro = 'DES_MOT_NO_RENOVACION';
              exception
                when others then
                  v_motivo := null;
              end;
          else
             v_motivo := null;
             begin
               select 'RENOVAR'
                 into v_ren_temporal
                 from cc_lin_sobregiros l, ba_personas p
                where l.nro_secuencia = k.nro_lin_sob_temporal
                  and l.tipo = 'T'
                  and l.estado = 'A'
                  and instr(','|| v_cod_campanas ||',' ,  ','||l.cod_campana||',') > 0
                  and instr(','|| v_cod_rub_eco_ren ||',' ,  ','||l.cod_rub_economico||',') > 0
                  and l.cod_persona = p.cod_persona
                  and p.tipo = 'F'
                  and not exists (select 1
                                    from cc_lin_sobregiros ls, cc_cta_corrientes cc
                                   where ls.nro_sec_padre = l.nro_secuencia
                                     and ls.nro_cuenta = cc.nro_cuenta
                                     and cc.cod_ente is not null);
              exception
                when others then
                  v_ren_temporal := null;
              end;
          end if;
        end if;

        v_texto := v_texto || k.cod_persona || chr(9) ||
                   lpad(k.nom_completo, 40, ' ') || chr(9) ||
                   lpad(k.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(k.cod_moneda, 3, ' ') || chr(9) ||
                   to_char(lpad(nvl(k.can_dias, 0), 8, ' ')) || chr(9) ||
                   to_char(lpad(nvl(k.can_dias_sobregiro, 0), 12, ' ')) ||
                   chr(9) ||

                    lpad(nvl(k.mto_lin_permanente,0), 20, ' ')||
                    chr(9) ||
                   LPAD(NVL(K.FEC_VTO_LIN_PERMANENTE, '00/00/0000'), 18, ' ')

                   || chr(9) ||
                   lpad(nvl(k.mto_lin_temporal, 0), 20, ' ') ||
                   chr(9) ||

                   LPAD(NVL((K.FEC_VTO_LIN_TEMPORAL), '00/00/0000'), 16, ' ') ||
                   CHR(9) ||
                    lpad(nvl(v_ren_temporal,' '), 20, ' ') || chr(9) ||
                    lpad(nvl(substr(v_motivo,1,60),' '), 60, ' ') || chr(9) ||
                    lpad(nvl(k.saldo,0), 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-01-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for l in detalle_02(c.cod_usu_oficial) loop
        if BAND <> 2 then
          BAND    := 2;
          v_texto := v_texto || chr(13) || chr(10) || l.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          l.cod_reporte) || chr(13);
          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||

                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 35, ' ') || chr(9) ||
                     lpad('Vto_Capital', 12, ' ') || chr(9) ||
                     lpad('Estado', 20, ' ') || chr(9) ||
                     lpad('Cuota', 10, ' ') || chr(9) ||
                     lpad('Vto_cuota', 15, ' ') || chr(9) ||
                     lpad('Dia_Mora', 8, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) ||
                     lpad('Sal_Cap_Cuota', 20, ' ') || chr(9) ||
                     lpad('Sal_cap_operacion', 20, ' ') || chr(13) || chr(10);
        end if;
        v_texto := v_texto || l.cod_persona || chr(9) ||
                   lpad(l.nom_completo, 40, ' ') || chr(9) ||
                   lpad(l.nro_cuenta, 15, ' ') || chr(9) ||

                   lpad(l.Telefono, 16, ' ') || chr(9) ||
                   lpad(l.tipo, 35, ' ') || chr(9) ||

                   lpad(nvl((l.fec_vencimiento), '00/00/0000'), 12, ' ') ||
                   chr(9) ||


                   lpad(l.estado, 20, ' ') || chr(9) ||
                   lpad(l.cuota, 10, ' ') || chr(9) ||

                   lpad(nvl((l.fec_Ven_cuota), '00/00/0000'), 15, ' ') ||
                   chr(9) ||



                   to_char(lpad(l.dia_mora, 8, ' ')) || chr(9) ||
                    lpad(l.cod_moneda, 3, ' ') || chr(9) ||
                    lpad(l.sal_cap_cuota, 20, ' ') || chr(9) ||
                    lpad(l.sal_cap_operacion, 20, ' ') ||
                   chr(13) || chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-02-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for m in detalle_03(c.cod_usu_oficial) loop
        if BAND <> 3 then
          BAND    := 3;
          v_texto := v_texto || chr(13) || chr(10) || m.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          m.cod_reporte) || chr(13) ||
                     chr(10);
          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) ||
                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Saldo', 20, ' ') || chr(9) ||
                     lpad('Saldo_Mon_local', 20, ' ') || chr(13) || chr(10);
        end if;
        v_texto := v_texto || m.cod_persona || chr(9) ||
                   lpad(m.nom_completo, 40, ' ') || chr(9) ||
                   lpad(m.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(m.cod_moneda, 3, ' ') || chr(9) ||
                   lpad(m.Telefono, 16, ' ') || chr(9) ||
                   lpad(m.tipo, 40, ' ') || chr(9) ||
                    lpad(m.saldo, 20, ' ') || chr(9) ||
                    lpad(m.sal_mon_local, 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-03-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for n in detalle_04(c.cod_usu_oficial) loop
        if BAND <> 4 then
          BAND    := 4;
          v_texto := v_texto || chr(13) || CHR(10) || n.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          n.cod_reporte) || chr(13) ||
                     chr(10);
          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||

                     lpad('Descripción', 40, ' ') || chr(9) ||
                     LPAD('Tip_valor', 9, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Fec_vigencia', 13, ' ') || chr(9) ||
                     lpad('Vencimiento', 12, ' ') || chr(9) ||
                     lpad('Val_tasa', 8, ' ') || chr(9) ||
                     lpad('Val_extension', 13, ' ') || chr(13) || chr(10);
        end if;
        v_texto := v_texto || n.cod_persona || chr(9) ||
                   lpad(n.nom_completo, 40, ' ') || chr(9) ||

                   lpad(n.descripcion, 40, ' ') || chr(9) ||
                   lpad(n.tip_valor, 9, ' ') || chr(9) ||
                   lpad(n.tipo, 40, ' ') || chr(9) ||
                   lpad(nvl((n.fec_vigencia), '00/00/0000'), 13, ' ') ||
                   chr(9) ||
                   lpad(nvl((n.fec_vencimiento), '00/00/0000'), 12, ' ') ||
                   chr(9) || to_char(lpad(n.val_tasa, 8, ' ')) || chr(9) ||
                   lpad(n.val_extension, 13, ' ') || chr(13) || chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-04-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for o in detalle_05(c.cod_usu_oficial) loop
        if BAND <> 5 then
          BAND    := 5;
          v_texto := v_texto || chr(13) || CHR(10) || O.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          o.cod_reporte) || chr(13) ||
                     chr(10);
          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Vencimiento', 13, ' ') || chr(9) ||
                     lpad('Estado', 15, ' ') || chr(9) || lpad('Mon', 3, ' ') ||
                     chr(9) || lpad('Cuota', 10, ' ') || chr(9) ||
                     lpad('Sal_cap_operacion', 20, ' ') || chr(9) ||
                     lpad('Fec_ren_tas_orig', 16, ' ') || chr(9) ||
                     lpad('Tas_actual', 10, ' ') || chr(13) || chr(10);
        end if;
        v_texto := v_texto || o.cod_persona || chr(9) ||
                   lpad(o.nom_completo, 40, ' ') || chr(9) ||
                   lpad(o.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(o.telefono, 16, ' ') || chr(9) ||
                   lpad(o.tipo, 40, ' ') || chr(9) ||

                   lpad(nvl((o.fec_vencimiento), '00/00/0000'), 13, ' ') ||
                   chr(9) ||

                   lpad(o.estado, 15, ' ') || chr(9) ||
                   lpad(o.cod_moneda, 3, ' ') || chr(9) || o.cuota || chr(9) ||

                  lpad(o.sal_cap_operacion, 20, ' ') ||
                   chr(9) ||

                   lpad(nvl((o.fec_ren_Tas_orig), '00/00/0000'), 16, ' ') ||
                   chr(9) ||

                   lpad(o.tas_actual, 10, ' ') || chr(13) || chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-05-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for p in detalle_06(c.cod_usu_oficial) loop
        if BAND <> 6 then
          BAND    := 6;
          v_texto := v_texto || chr(13) || CHR(10) || P.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          p.cod_reporte) || chr(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Vencimiento', 13, ' ') || chr(9) ||
                     lpad('Estado', 15, ' ') || chr(9) || lpad('Mon', 3, ' ') ||
                     chr(9) || lpad('Capital', 20, ' ') || chr(9) ||
                     lpad('Sal_int_vencido', 20, ' ') || chr(9) ||
                     lpad('Sal_cap_operacion', 20, ' ') || chr(09) ||
                     lpad('Sal_bloqueado', 20, ' ') || chr(13) || chr(10); --DYDMR-3870
        end if;
        v_texto := v_texto || P.COD_PERSONA || CHR(9) ||
                   lpad(p.nom_completo, 40, ' ') || chr(9) ||
                   lpad(p.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(p.telefono, 16, ' ') || chr(9) ||
                   lpad(p.tipo, 40, ' ') || chr(9) ||
                   lpad(nvl((p.fec_vencimiento), '00/00/0000'), 13, ' ') || chr(9) ||
                   lpad(p.estado, 15, ' ') || chr(9) ||
                   lpad(p.cod_moneda, 3, ' ') || chr(9) ||
                   lpad(p.capital, 20, ' ') || chr(9) ||
                   lpad(p.sal_int_vencido, 20, ' ') || chr(9) ||
                   lpad(p.sal_cap_operacion, 20, ' ') || chr(9) ||
                   lpad(p.monto, 20, ' ') || chr(13) || chr(10); --DYDMR-3870
      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-06-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      for q in detalle_07(c.cod_usu_oficial) loop
        if BAND <> 7 then
          BAND    := 7;
          v_texto := v_texto || chr(13) || CHR(10) || Q.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          q.cod_reporte) || chr(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Dia_mora', 8, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) || lpad('Saldo', 20, ' ') ||
                     chr(9) || lpad('Lin_credito', 20, ' ') || chr(13) ||
                     chr(10);
        end if;
        v_texto := v_texto || q.cod_persona || chr(9) ||
                   lpad(q.nom_completo, 40, ' ') || chr(9) ||
                   lpad(q.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(q.telefono, 16, ' ') || chr(9) ||
                   lpad(q.tipo, 40, ' ') || chr(9) ||
                   lpad(q.dia_mora, 8, ' ') || chr(9) ||
                   lpad(q.cod_moneda, 3, ' ') || chr(9) ||
                  lpad(q.saldo, 20, ' ') || chr(9) ||
                   lpad(q.lin_credito, 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-07-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      ---

      for r in detalle_08(c.cod_usu_oficial) loop
        if BAND <> 8 then
          BAND    := 8;
          v_texto := v_texto || chr(13) || CHR(10) || R.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          r.cod_reporte) || chr(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Teléfono', 16, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Cod_tra_padre', 13, ' ') || chr(9) ||
                     lpad('Des_tra_padre', 70, ' ') || chr(9) ||
                     lpad('Cod_transaccion', 13, ' ') || chr(9) ||
                     lpad('Des_transaccion', 70, ' ') || chr(9) ||
                     lpad('Nro_Documento', 15, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) || 'Monto' || chr(13) ||
                     chr(10);
        end if;
        v_texto := v_texto || r.cod_persona || chr(9) ||
                   lpad(r.nom_completo, 40, ' ') || chr(9) ||
                   lpad(r.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(r.telefono, 16, ' ') || chr(9) ||
                   lpad(r.tipo, 40, ' ') || chr(9) ||
                   lpad(r.cod_tra_padre, 13, ' ') || chr(9) ||
                   lpad(r.des_tra_padre, 70, ' ') || chr(9) ||
                   lpad(r.cod_Transaccion, 13, ' ') || chr(9) ||
                   lpad(r.des_transaccion, 70, ' ') || chr(9) ||
                   lpad(r.Nro_documento, 15, ' ') || chr(9) ||
                   lpad(r.cod_moneda, 3, ' ') || chr(9) ||

                  lpad(r.monto, 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-08-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      ---

      for s in detalle_09(c.cod_usu_oficial) loop
        if BAND <> 9 then
          BAND    := 9;
          v_texto := v_texto || chr(13) || CHR(10) || S.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          s.cod_reporte) || chr(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_cuenta', 15, ' ') || chr(9) ||
                     lpad('Estado', 40, ' ') || chr(9) ||
                     lpad('Vencimiento', 13, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) || lpad('Saldo', 20, ' ') ||
                     chr(9) || lpad('Cod_Oficina', 11, ' ') || chr(9) ||
                     lpad('Cod_modalidad', 13, ' ') || chr(9) ||
                     lpad('Des_modalidad', 40, ' ') || chr(13) || chr(10);
        end if;
        v_texto := v_texto || s.cod_persona || chr(9) ||
                   lpad(s.nom_completo, 40, ' ') || chr(9) ||
                   lpad(s.nro_cuenta, 15, ' ') || chr(9) ||
                   lpad(s.estado, 40, ' ') || chr(9) ||
                   lpad(nvl((s.fec_vencimiento), '00/00/0000'), 13, ' ') ||
                   chr(9) || lpad(s.cod_moneda, 3, ' ') || chr(9) ||

                   lpad(s.saldo, 20, ' ') || chr(9) ||
                   to_char(lpad(s.cod_oficina, 11, ' ')) || chr(9) ||
                   to_char(lpad(s.cod_modalidad, 13, ' ')) || chr(9) ||
                   lpad(s.des_modalidad, 40, ' ') || chr(13) || chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-09-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      ------------

      for t in detalle_10(c.cod_usu_oficial) loop
        if BAND <> 10 then
          BAND    := 10;
          v_texto := v_texto || chr(13) || CHR(10) || T.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          t.cod_reporte) || chr(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nro_Garantia', 15, ' ') || chr(9) ||
                     lpad('Tipo', 40, ' ') || chr(9) ||
                     lpad('Estado', 40, ' ') || chr(9) ||
                     lpad('Vencimiento', 13, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) || lpad('Valor', 20, ' ') ||
                     chr(9) || lpad('Mto_aplicado', 20, ' ') || chr(13) ||
                     chr(10);
        end if;

        v_texto := v_texto || t.cod_persona || chr(9) ||
                   to_char(lpad(t.nro_garantia, 15, ' ')) || chr(9) ||
                   lpad(t.tipo, 40, ' ') || chr(9) || lpad(t.estado, 40, ' ') ||
                   chr(9) ||

                   lpad(nvl((t.fec_vencimiento), '00/00/0000'), 13, ' ') ||
                   chr(9) || lpad(t.cod_moneda, 3, ' ') || chr(9) ||

                  lpad(t.valor, 20, ' ') || chr(9) ||

                   lpad(t.mto_aplicado, 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-10-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      -----

      for u in detalle_11(c.cod_usu_oficial) loop
        if BAND <> 11 then
          BAND    := 11;
          v_texto := v_texto || chr(13) || CHR(10) || U.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          u.cod_reporte) || CHR(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Nro_Linea', 7, ' ') || chr(9) ||
                     lpad('Fec_otorgamiento', 16, ' ') || chr(9) ||
                     lpad('Vencimiento', 13, ' ') || chr(9) ||
                     lpad('Niv_Aprobacion', 20, ' ') || chr(9) ||
                     lpad('Mon', 3, ' ') || chr(9) || lpad('Monto', 20, ' ') ||
                     CHR(13) || chr(10);
        end if;

        v_texto := v_texto || u.cod_persona || chr(9) ||
                   lpad(u.nom_completo, 40, ' ') || chr(9) ||
                   lpad(u.nro_linea, 7, ' ') || chr(9) ||
                   lpad(nvl((u.fec_otorgamiento), '00/00/0000'), 13, ' ') ||
                   chr(9) ||
                   lpad(nvl((u.fec_vencimiento), '00/00/0000'), 13, ' ') ||
                   chr(9) || lpad(u.niv_aprobacion, 20, ' ') || chr(9) ||
                   lpad(u.cod_moneda, 3, ' ') || chr(9) ||
                   lpad(u.monto, 20, ' ') || chr(13) ||
                   chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-11-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      -----

      for v in detalle_12(c.cod_usu_oficial) loop
        if BAND <> 12 then
          BAND    := 12;
          v_texto := v_texto || chr(13) || CHR(10) || V.cod_reporte || '-' ||
                     fue_obt_des_refcodes('COD_REP_POS_CLIENTE',
                                          v.cod_reporte) || CHR(13) ||
                     chr(10);

          v_texto := v_Texto || 'Persona' || chr(9) ||
                     lpad('Nom_completo', 40, ' ') || chr(9) ||
                     lpad('Fec_Nacimiento', 14, ' ') || CHR(13) || chr(10);
        end if;

        v_texto := v_texto || v.cod_persona || chr(9) ||
                   lpad(v.nom_completo, 40, ' ') || chr(9) ||
                   lpad(nvl((v.fec_nacimiento), '00/00/0000'), 13, ' ') ||
                   CHR(13) || chr(10);

      end loop;
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('DETALLE-12-'||c.cod_usu_oficial,v_hor_ini,v_hor_fin);
      v_hor_ini := to_char(sysdate,'hh24:mi:ss');
      -----
      if nvl(v_env_mail_gestor,'S') = 'S' then
        v_dir_destino := v_dir_correo_ofi;
      else
        -- Envía el mail al sau
        v_dir_destino := fug_obt_pardinamico('CAM_MAR_DIR_SAU');
      end if;
      if v_tex_notificacion is not null then
        v_tex_mail := v_tex_notificacion|| CHR(13) ||chr(10)||'Posiciones de Clientes por Gestor';
      else
        v_tex_mail := 'Posiciones de Clientes por Gestor';
      end if;
      it_mail.mail_attach(v_dir_correo,
                          v_dir_destino,
                          'Posiciones de clientes_'||c.cod_usu_oficial,
                          v_tex_mail,
                          v_texto,
                          c.cod_usu_oficial || '_' || v_fecha );
      v_hor_fin := to_char(sysdate,'hh24:mi:ss');
      lp_logeo('ENVIO_MAIL',v_hor_ini,v_hor_fin);
    end if;
  end loop;

  v_hor_finff := to_char(sysdate,'hh24:mi:ss');
  lp_logeo('FULL',v_hor_iniff,v_hor_finff);

end;
/

