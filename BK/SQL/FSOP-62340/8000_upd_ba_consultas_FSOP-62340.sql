begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ba_consultas a 
set a.det_sql = 'SELECT pers.nro_documento ,
              cli.cod_persona nro_persona,
              cli.nom_cliente den_cliente,
              cue.nro_cuenta,
              cue.tip_cuenta,
              to_char(mov.fec_movimiento,''DD/MM/RRRR'') fec_movimiento,
              mov.hor_movimiento,
              mov.nro_documento nro_operacion,
              m.concepto descripcion,
              cue.cod_moneda moneda,
              mov.mto_debito ,
              mov.mto_credito ,
              fug_obt_sal_act_extractos(mov.fec_extracto,cue.nro_cuenta,mov.hor_movimiento,mov.fec_movimiento,mov.mto_debito,mov.mto_credito) sal_actual,
              m.cod_tra_padre cod_transaccion,
              m.des_tra_padre transaccion 
        FROM ge_ext_clientes cli,
             ge_ext_cli_cuentas cue,
             ge_ext_cli_movimientos mov,
             ba_personas pers,
             gv_movimientos m,
             ge_transacciones c
        where    pers.cod_persona=cli.cod_persona
        AND      cli.cod_persona=cue.cod_persona
        AND      cli.cod_extracto=cue.cod_extracto
        AND      cli.fre_extracto=cue.fre_extracto
        AND      cli.fec_extracto=cue.fec_extracto
        AND      cli.cod_persona=mov.cod_persona
        AND      cue.fec_extracto=mov.fec_extracto
        AND      cue.nro_cuenta=mov.nro_cuenta
        AND      m.TIPO = ''H''
        and      m.ESTADO not in (''X'', ''P'', ''J'')
        and      c.cod_modulo = m.cod_modulo
        and      c.cod_modalidad = m.cod_modalidad
        and      c.cod_transaccion = m.cod_transaccion
        and      c.ve_cliente = ''S''
        and      m.fecha=mov.fec_movimiento
        and      m.HORA=mov.hor_movimiento
        and      m.NRO_SECUENCIA=mov.nro_secuencia
        and      m.NRO_CUENTA=cue.nro_cuenta
        and      not m.monto is null
        AND ('||'&'||'P_FILTROS)
        order by m.fec_insercion'
where a.cod_consulta = 'CD_EXT_BAN';

commit;
