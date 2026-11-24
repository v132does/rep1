create or replace procedure it.PRG_INS_CLI_CTA_ATRASOS is
  v_error            VARCHAR2(2000);
  v_inc_per_fisica   VARCHAR2(1) := fue_obt_val_max_refcodes('TIP_PER_COB_24X7','PER_FIS');
  v_inc_per_juridica VARCHAR2(1) := fue_obt_val_max_refcodes('TIP_PER_COB_24X7','PER_JUR');
  v_fecha            DATE        := pag_cal.fu_obt_fec_actual(5);
begin
  sql_util.ejecute_dml('truncate table ge_cli_cta_atrasos', v_error);
  IF v_error IS NOT NULL THEN
    raise_application_error(-20000,
                            'Error en PRG_INS_CLI_CTA_ATRASOS_1 ' ||
                            v_error);
  END IF;
  If nvl(fug_obt_pardinamico('ACT_COB_24X7'), 'N') = 'S' then
    Begin
      Insert into ge_cli_cta_atrasos
        select o.cod_persona,o.nro_cuenta,o.cod_modulo,
               o.cod_modalidad,o.cod_estado,nvl(ta.mto_mora, 0),
               o.dia_atraso,o.cod_moneda,o.cod_oficina,
               'N',null,'N',
               0,null,user,
               sysdate,null,null,
               null,null,null,
               null,null,null
          from ge_cla_operaciones o,
               ba_personas        p,
               ge_par_dinamicos   d,
               ge_par_dinamicos   d2,
               ge_clientes        c,
               ba_usuarios        us,
               ge_par_dinamicos   d3,
               ta_cta_tarjetas    ta
         where o.cod_modulo = 5
           and o.cod_persona = p.cod_persona
           and ((v_inc_per_fisica= 'S' and p.tipo = 'F') or
               (v_inc_per_juridica = 'S' and p.tipo = 'J'))
           and o.cod_modulo = d.cod_modulo
           and d.parametro = 'MOD_COB_24X7'
           and d.val_parametro = 'S'
           and o.cod_modulo = d2.cod_modulo(+)
           and o.cod_modalidad = d2.cod_modalidad(+)
           and d2.parametro(+) = 'MAD_COB_24X7'
           and nvl(d2.val_parametro, 'N') = 'S'
           and o.cod_persona = c.cod_persona
           and c.cod_usu_oficial = us.cod_usuario
           and us.cod_oficina = d3.cod_oficina(+)
           and d3.parametro(+) = 'EXC_OFI_GES_COB_24X7'
           and nvl(d3.val_parametro, 'N') <> 'S'
           and o.nro_cuenta = ta.nro_cuenta(+)
           and o.cod_modulo = ta.cod_modulo(+)
           and o.cod_modalidad = ta.cod_modalidad(+)
           and not exists (select 1
                             from ge_per_inhibidas x, ge_par_dinamicos d4
                            where x.cod_persona = o.cod_persona
                              and x.estado = 'I'
                              and d4.parametro = 'CAU_INH_COB_24X7'
                              and instr(d4.val_parametro, x.cod_causa) > 0)
           AND TA.MTO_MORA > (SELECT NVL(SUM(T.MONTO), 0)
                                FROM TA_COBROS T
                               WHERE T.NRO_CUENTA = O.NRO_CUENTA
                                 AND T.FEC_PROCESO = v_fecha
                                 AND T.ESTADO <> 'E'
                                 AND T.EST_ENVIO = 'E')
        UNION ALL
        select o.cod_persona,o.nro_cuenta,o.cod_modulo,
               o.cod_modalidad,o.cod_estado,nvl(pr.mto_mora, 0),
               o.dia_atraso,o.cod_moneda,o.cod_oficina,
               'N',null,'N',
               0,null,user,
               sysdate,null,null,
               null,null,null,
               null,null,null
          from ge_cla_operaciones o,
               ba_personas        p,
               ge_par_dinamicos   d,
               ge_par_dinamicos   d2,
               ge_clientes        c,
               ba_usuarios        us,
               ge_par_dinamicos   d3,
               pr_cta_prestamos   pr,
               pr_solicitudes     ps,
              (Select nro_cuenta, count(1) cant_cuo
               from pr_cuotas
              where mto_capital <> 0 
           group by nro_cuenta) cu
         where o.cod_modulo = 6
           and o.cod_persona = p.cod_persona
           and ((v_inc_per_fisica = 'S' and p.tipo = 'F') or
               (v_inc_per_juridica = 'S' and p.tipo = 'J'))
           and o.cod_modulo = d.cod_modulo
           and d.parametro = 'MOD_COB_24X7'
           and d.val_parametro = 'S'
           and o.cod_modulo = d2.cod_modulo(+)
           and o.cod_modalidad = d2.cod_modalidad(+)
           and d2.parametro(+) = 'MAD_COB_24X7'
           and nvl(d2.val_parametro, 'N') = 'S'
           and o.cod_persona = c.cod_persona
           and c.cod_usu_oficial = us.cod_usuario
           and us.cod_oficina = d3.cod_oficina(+)
           and d3.parametro(+) = 'EXC_OFI_GES_COB_24X7'
           and nvl(d3.val_parametro, 'N') <> 'S'
           and o.nro_cuenta = pr.nro_cuenta(+)
           and o.cod_modulo = pr.cod_modulo(+)
           and o.cod_modalidad = pr.cod_modalidad(+)
           /*Préstamos con cuotas mensuales p/ PYMES*/
           and pr.nro_solicitud = ps.nro_solicitud   
           and o.nro_cuenta = cu.nro_cuenta
           /*---------------------------------------*/                 
           and not exists (select 1
                             from ge_per_inhibidas x, ge_par_dinamicos d4
                            where x.cod_persona = o.cod_persona
                              and x.estado = 'I'
                              and d4.parametro = 'CAU_INH_COB_24X7'
                              and instr(d4.val_parametro, x.cod_causa) > 0)
          
        /*Préstamos con cuotas NO mensuales p/ PYMES*/
        UNION ALL  
        select o.cod_persona,o.nro_cuenta,o.cod_modulo,
               o.cod_modalidad,o.cod_estado,nvl(pr.mto_mora, 0),
               o.dia_atraso,o.cod_moneda,o.cod_oficina,
               'N',null,'N',
               0,null,user,
               sysdate,null,null,
               null,null,null,
               null,null,null
          from ge_cla_operaciones o,
               ba_personas        p,
               ge_par_dinamicos   d,
               ge_par_dinamicos   d2,
               ge_clientes        c,
               ba_usuarios        us,
               ge_par_dinamicos   d3,
               ge_par_dinamicos   d4,
               pr_cta_prestamos   pr,
               pr_solicitudes     ps,
              (Select nro_cuenta, count(1) cant_cuo
               from pr_cuotas
              where mto_capital <> 0 
           group by nro_cuenta) cu
         where o.cod_modulo = 6
           and o.cod_persona = p.cod_persona
           and ((v_inc_per_fisica = 'S' and p.tipo = 'F') or
               (v_inc_per_juridica = 'S' and p.tipo = 'J'))
           and o.cod_modulo = d.cod_modulo
           and d.parametro = 'MOD_COB_24X7'
           and d.val_parametro = 'S'
           and o.cod_modulo = d2.cod_modulo(+)
           and o.cod_modalidad = d2.cod_modalidad(+)
           and d2.parametro(+) = 'MAD_COB_24X7'
           and nvl(d2.val_parametro, 'N') = 'S'
           and o.cod_persona = c.cod_persona
           and c.cod_usu_oficial = us.cod_usuario
           and us.cod_oficina = d3.cod_oficina(+)
           and d3.parametro(+) = 'EXC_OFI_GES_COB_24X7'
           and nvl(d3.val_parametro, 'N') <> 'S'
           and o.nro_cuenta = pr.nro_cuenta(+)
           and o.cod_modulo = pr.cod_modulo(+)
           and o.cod_modalidad = pr.cod_modalidad(+)
           and d4.parametro = 'CAN_DIA_ATR_PYM_24X7'
           and o.dia_atraso >= d4.val_parametro
           and pr.nro_solicitud = ps.nro_solicitud  
           and o.nro_cuenta = cu.nro_cuenta
           and ((ps.per_vto_capital not in (30,31) and cu.cant_cuo > 1) or cu.cant_cuo = 1)
           and not exists (select 1
                             from ge_per_inhibidas x, ge_par_dinamicos d4
                            where x.cod_persona = o.cod_persona
                              and x.estado = 'I'
                              and d4.parametro = 'CAU_INH_COB_24X7'
                              and instr(d4.val_parametro, x.cod_causa) > 0)
          /*OPERECIONES VENCIDAS*/
          UNION ALL
          select o.cod_persona,o.nro_cuenta,o.cod_modulo,
               o.cod_modalidad,o.cod_estado,nvl(ov.sal_total, 0),
               o.dia_atraso,o.cod_moneda,o.cod_oficina,
               'N',null,'N',
               0,null,user,
               sysdate,null,null,
               null,null,null,
               null,null,null
          from ge_cla_operaciones o,
               ba_personas        p,
               ge_par_dinamicos   d,
               ge_par_dinamicos   d2,
               ge_clientes        c,
               ba_usuarios        us,
               ge_par_dinamicos   d3,
               ov_cta_vencidas    ov
         where o.cod_modulo = 15
           and o.cod_persona = p.cod_persona
           and ((v_inc_per_fisica = 'S' and p.tipo = 'F') or
               (v_inc_per_juridica = 'S' and p.tipo = 'J'))
           and o.cod_modulo = d.cod_modulo
           and d.parametro = 'MOD_COB_24X7'
           and d.val_parametro = 'S'
           and o.cod_modulo = d2.cod_modulo(+)
           and o.cod_modalidad = d2.cod_modalidad(+)
           and d2.parametro(+) = 'MAD_COB_24X7'
           and nvl(d2.val_parametro, 'N') = 'S'
           and o.cod_persona = c.cod_persona
           and c.cod_usu_oficial = us.cod_usuario
           and us.cod_oficina = d3.cod_oficina(+)
           and d3.parametro(+) = 'EXC_OFI_GES_COB_24X7'
           and nvl(d3.val_parametro, 'N') <> 'S'
           and o.nro_cuenta = ov.nro_cuenta(+)
           and o.cod_modulo = ov.cod_modulo(+)
           and o.cod_modalidad = ov.cod_modalidad(+)             
           and not exists (select 1
                             from ge_per_inhibidas x, ge_par_dinamicos d4
                            where x.cod_persona = o.cod_persona
                              and x.estado = 'I'
                              and d4.parametro = 'CAU_INH_COB_24X7'
                              and instr(d4.val_parametro, x.cod_causa) > 0);
    Exception
      When no_data_found then
        null;
      When others then
        raise_application_error(-20000,
                                'Error en PRG_INS_CLI_CTA_ATRASOS_2 ' ||
                                sqlerrm);
    End;
  End If;
end PRG_INS_CLI_CTA_ATRASOS;
/

