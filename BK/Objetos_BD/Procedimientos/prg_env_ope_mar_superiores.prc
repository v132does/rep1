create or replace procedure it.PRG_ENV_OPE_MAR_SUPERIORES is

  --Archivo
  v_cabecera varchar2(32767);
  v_detalles varchar2(32767);
  --Correo Electronico
  v_dir_correo     ba_personas.dir_correo%type := fug_obt_dir_correo;
  v_dir_correo_usu ba_personas.dir_correo%type := fug_obt_pardinamico('EMAIL_ENV_OPE_SUPERI');
  --Acceso FTP
  v_file              utl_file.file_type;
  v_directorio        varchar2(20) := pag_evo.g_repository;
  v_name              varchar2(128);
  v_separador         varchar2(10) := chr(9);
  g_ip                varchar2(100) := pag_evo.g_ip;
  g_port              varchar2(100) := pag_evo.g_port;
  g_user              varchar2(100) := pag_evo.g_user;
  g_pass              varchar2(100) := pag_evo.g_pass;
  v_directorio_ramail varchar2(100) := pag_evo.g_contabilidad;

  v_fec_actual date := pag_cal.fu_obt_fec_actual(1);

  cursor c_ope_mar_superi is
  
    select c.fec_apertura,
           a.fecha,
           v_fec_actual fecha_operacion,
           v_fec_actual fecha_vencimiento,
           e.cod_persona,
           x.nom_completo,
           a.cod_oficina,
           f.descripcion descripcion_oficina,
           b.nro_cuenta,
           c.denominacion denominacion_cuenta,
           a.cod_modalidad,
           g.descripcion descripcion_modalidad,
           a.cod_moneda,
           b.sal_actual monto,
           b.sal_actual monto_moneda_local,
           fug_obt_val_tasa(a.cod_modulo,
                            a.cod_modalidad,
                            a.cod_oficina,
                            b.nro_cuenta,
                            a.cod_moneda,
                            null,
                            c.tas_personalizada,
                            c.cod_tasa,
                            null,
                            v_fec_actual) tasa_nominal,
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              decode(c.tip_capitalizacion,
                                     1,
                                     30,
                                     2,
                                     60,
                                     3,
                                     90,
                                     4,
                                     120,
                                     6,
                                     180,
                                     12,
                                     365,
                                     99,
                                     d.can_dias,
                                     null)) tasa_efectiva,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 150 / 100 tasa_base,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) tasa_pizarra,
           decode(c.tip_capitalizacion,
                  1,
                  30,
                  2,
                  60,
                  3,
                  90,
                  4,
                  120,
                  6,
                  180,
                  12,
                  365,
                  99,
                  d.can_dias,
                  null) plazo,
           a.cod_rubro,
           b.sal_actual /
           (select abs(c.sal_mon_loc_ant + c.deb_equ_local - c.cre_mon_local) saldo
              from cb_sal_consolidados_dia c
             where c.cod_rubro = '200000000000000'
               and c.fecha = v_fec_actual) porcentaje_operacion,
           b.sal_actual +
           b.sal_actual /
           (select abs(c.sal_mon_loc_ant + c.deb_equ_local - c.cre_mon_local) saldo
              from cb_sal_consolidados_dia c
             where c.cod_rubro = '200000000000000'
               and c.fecha = v_fec_actual) monto_porcentaje
    
      from cb_sal_inventarios_his a
      join cb_sal_inventarios_det_his b
        on a.nro_referencia = b.nro_referencia
       and a.fecha = b.fecha
      join ah_cta_vistas c
        on b.nro_cuenta = c.nro_cuenta
      join ge_plz_contables d
        on a.cod_plazo = d.cod_plazo
      join ge_cta_clientes e
        on b.nro_cuenta = e.nro_cuenta
       and e.relacion = 'P'
      join ba_oficinas f
        on a.cod_oficina = f.cod_oficina
      join ge_modalidades g
        on g.cod_modalidad = a.cod_modalidad
      join ba_personas x
        on x.cod_persona = e.cod_persona
     where (substr(a.cod_rubro, 6, 3) in (102, 196, 236, 292, 238) or
           (substr(a.cod_rubro, 6, 3) in (138) and
           substr(a.cod_rubro, 9, 2) in (02, 03)))
       and (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 150 / 100 <
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              decode(c.tip_capitalizacion,
                                     1,
                                     30,
                                     2,
                                     60,
                                     3,
                                     90,
                                     4,
                                     120,
                                     6,
                                     180,
                                     12,
                                     365,
                                     99,
                                     d.can_dias,
                                     null))
       and a.cod_modalidad = 31
       and a.cod_moneda in ('GS')
       and a.fecha = v_fec_actual
       and a.tip_saldo = 'C'
       and (to_char(c.fec_apertura, 'MM/YYYY') =
           to_char(v_fec_actual, 'MM/YYYY') OR
           c.nro_cuenta in (SELECT b.nro_cuenta
                               FROM gv_movimientos b
                              where b.COD_TRANSACCION in (100)
                                and to_char(b.FECHA, 'YYYY/MM') =
                                    to_char(v_fec_actual, 'MM/YYYY')
                                and b.NRO_CUENTA is not null
                                and b.REVERSADO = 'N'))
    
    UNION ALL
    
    --depositos a la vista usd
    
    select c.fec_apertura,
           a.fecha,
           v_fec_actual fecha_operacion,
           v_fec_actual fecha_vencimiento,
           e.cod_persona,
           x.nom_completo,
           a.cod_oficina,
           f.descripcion descripcion_oficina,
           b.nro_cuenta,
           c.denominacion denominacion_cuenta,
           a.cod_modalidad,
           g.descripcion descripcion_modalidad,
           a.cod_moneda,
           b.sal_actual monto,
           b.sal_actual *
           (pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) monto_moneda_local,
           fug_obt_val_tasa(a.cod_modulo,
                            a.cod_modalidad,
                            a.cod_oficina,
                            b.nro_cuenta,
                            a.cod_moneda,
                            null,
                            c.tas_personalizada,
                            c.cod_tasa,
                            null,
                            v_fec_actual) tasa_nominal,
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              decode(c.tip_capitalizacion,
                                     1,
                                     30,
                                     2,
                                     60,
                                     3,
                                     90,
                                     4,
                                     120,
                                     6,
                                     180,
                                     12,
                                     365,
                                     99,
                                     d.can_dias,
                                     null)) tasa_efectiva,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 250 / 100 tasa_base,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) tasa_pizarra,
           decode(c.tip_capitalizacion,
                  1,
                  30,
                  2,
                  60,
                  3,
                  90,
                  4,
                  120,
                  6,
                  180,
                  12,
                  365,
                  99,
                  d.can_dias,
                  null) plazo,
           a.cod_rubro,
           
           b.sal_actual *
           (pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) /
           (select abs(c.sal_mon_loc_ant + c.deb_equ_local - c.cre_mon_local) saldo
              from cb_sal_consolidados_dia c
             where c.cod_rubro = '200000000000000'
               and c.fecha = v_fec_actual) porcentaje_operacion,
           b.sal_actual *
           (pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) +
           b.sal_actual *
           (pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) /
           (select abs(c.sal_mon_loc_ant + c.deb_equ_local - c.cre_mon_local) saldo
              from cb_sal_consolidados_dia c
             where c.cod_rubro = '200000000000000'
               and c.fecha = v_fec_actual) monto_porcentaje
    
      from cb_sal_inventarios_his a
      join cb_sal_inventarios_det_his b
        on a.nro_referencia = b.nro_referencia
       and a.fecha = b.fecha
      join ah_cta_vistas c
        on b.nro_cuenta = c.nro_cuenta
      join ge_plz_contables d
        on a.cod_plazo = d.cod_plazo
      join ge_cta_clientes e
        on b.nro_cuenta = e.nro_cuenta
       and e.relacion = 'P'
      join ba_oficinas f
        on a.cod_oficina = f.cod_oficina
      join ge_modalidades g
        on g.cod_modalidad = a.cod_modalidad
    
      join ba_personas x
        on x.cod_persona = e.cod_persona
     where (substr(a.cod_rubro, 6, 3) in (102, 196, 236, 292, 238) or
           (substr(a.cod_rubro, 6, 3) in (138) and
           substr(a.cod_rubro, 9, 2) in (02, 03)))
       and (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   decode(c.tip_capitalizacion,
                                          1,
                                          30,
                                          2,
                                          60,
                                          3,
                                          90,
                                          4,
                                          120,
                                          6,
                                          180,
                                          12,
                                          365,
                                          99,
                                          d.can_dias,
                                          null),
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 250 / 100 <
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              decode(c.tip_capitalizacion,
                                     1,
                                     30,
                                     2,
                                     60,
                                     3,
                                     90,
                                     4,
                                     120,
                                     6,
                                     180,
                                     12,
                                     365,
                                     99,
                                     d.can_dias,
                                     null))
       and a.cod_modalidad = 31
       and a.cod_moneda in ('USD')
       and a.fecha = v_fec_actual
       and a.tip_saldo = 'C'
       and (to_char(c.fec_apertura, 'MM/YYYY') =
           to_char(v_fec_actual, 'MM/YYYY') or
           c.nro_cuenta in (SELECT b.nro_cuenta
                               FROM gv_movimientos b
                              where b.COD_TRANSACCION in (100)
                                and to_char(b.FECHA, 'YYYY/MM') =
                                    to_char(v_fec_actual, 'MM/YYYY')
                                and b.NRO_CUENTA is not null
                                and b.REVERSADO = 'N'))
    
    union all
    
    --cda gs
    select c.fec_apertura,
           a.fecha,
           c.fec_apertura fecha_operacion,
           c.fec_vencimiento fecha_vencimiento,
           e.cod_persona,
           x.nom_completo,
           a.cod_oficina,
           f.descripcion descripcion_oficina,
           b.nro_cuenta,
           c.denominacion denominacion_cuenta,
           a.cod_modalidad,
           g.descripcion descripcion_modalidad,
           a.cod_moneda,
           b.sal_actual monto,
           b.sal_actual monto_moneda_local,
           fug_obt_val_tasa(a.cod_modulo,
                            a.cod_modalidad,
                            a.cod_oficina,
                            b.nro_cuenta,
                            a.cod_moneda,
                            null,
                            c.tas_personalizada,
                            c.cod_tasa,
                            null,
                            v_fec_actual) tasa_nominal,
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              c.fec_vencimiento - c.fec_apertura) tasa_efectiva,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   c.fec_vencimiento - c.fec_apertura,
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 150 / 100 tasa_base,
           fug_obt_tas_efe_pizarra(a.cod_modulo,
                                  a.cod_modalidad,
                                  a.cod_moneda,
                                  b.sal_actual,
                                  c.fec_vencimiento - c.fec_apertura,
                                  c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)) tasa_pizarra,
           
           c.fec_vencimiento - c.fec_apertura plazo,
           a.cod_rubro,
           b.sal_actual / (select abs(ccd.sal_mon_loc_ant +
                                      ccd.deb_equ_local - ccd.cre_mon_local) saldo
                             from cb_sal_consolidados_dia ccd
                            where ccd.cod_rubro = '200000000000000'
                              and ccd.fecha = v_fec_actual) porcentaje_operacion,
           b.sal_actual +
           b.sal_actual / (select abs(ccd.sal_mon_loc_ant +
                                      ccd.deb_equ_local - ccd.cre_mon_local) saldo
                             from cb_sal_consolidados_dia ccd
                            where ccd.cod_rubro = '200000000000000'
                              and ccd.fecha = v_fec_actual) monto_porcentaje
    
      from cb_sal_inventarios_his a
      join cb_sal_inventarios_det_his b
        on a.nro_referencia = b.nro_referencia
       and a.fecha = b.fecha
      join ah_cta_certificados c
        on b.nro_cuenta = c.nro_cuenta
      join ge_plz_contables d
        on a.cod_plazo = d.cod_plazo
      join ge_cta_clientes e
        on b.nro_cuenta = e.nro_cuenta
       and e.relacion = 'P'
      join ba_oficinas f
        on a.cod_oficina = f.cod_oficina
      join ge_modalidades g
        on g.cod_modalidad = a.cod_modalidad
      join ba_personas x
        on x.cod_persona = e.cod_persona
     where substr(a.cod_rubro, 6, 3) in (104, 156, 298, 306)
       and ((fug_obt_tas_efe_pizarra(a.cod_modulo,
                                    a.cod_modalidad,
                                    a.cod_moneda,
                                    b.sal_actual,
                                    c.fec_vencimiento - c.fec_apertura,
                                    c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 150 / 100) <
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              c.fec_vencimiento - c.fec_apertura)
       and a.cod_modalidad = 33
       and a.cod_moneda in ('GS')
       and a.fecha = v_fec_actual
       and a.tip_saldo = 'C'
       and to_char(c.fec_apertura, 'MM/YYYY') =
           to_char(v_fec_actual, 'MM/YYYY')
    
    UNION ALL
    
    --cda usd
    
    select c.fec_apertura,
           a.fecha,
           c.fec_apertura fecha_operacion,
           c.fec_vencimiento fecha_vencimiento,
           e.cod_persona,
           x.nom_completo,
           a.cod_oficina,
           f.descripcion descripcion_oficina,
           b.nro_cuenta,
           c.denominacion denominacion_cuenta,
           a.cod_modalidad,
           g.descripcion descripcion_modalidad,
           a.cod_moneda,
           b.sal_actual monto,
           b.sal_actual monto_moneda_local,
           fug_obt_val_tasa(a.cod_modulo,
                            a.cod_modalidad,
                            a.cod_oficina,
                            b.nro_cuenta,
                            a.cod_moneda,
                            null,
                            c.tas_personalizada,
                            c.cod_tasa,
                            null,
                            v_fec_actual) tasa_nominal,
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              c.fec_vencimiento - c.fec_apertura) tasa_efectiva,
           (fug_obt_tas_efe_pizarra(a.cod_modulo,
                                   a.cod_modalidad,
                                   a.cod_moneda,
                                   b.sal_actual,
                                   c.fec_vencimiento - c.fec_apertura,
                                   c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 250 / 100 tasa_base,
           fug_obt_tas_efe_pizarra(a.cod_modulo,
                                  a.cod_modalidad,
                                  a.cod_moneda,
                                  b.sal_actual,
                                  c.fec_vencimiento - c.fec_apertura,
                                  c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta)) tasa_pizarra,
           
           c.fec_vencimiento - c.fec_apertura plazo,
           a.cod_rubro,
           b.sal_actual / (select abs(ccd.sal_mon_loc_ant +
                                      ccd.deb_equ_local - ccd.cre_mon_local) saldo
                             from cb_sal_consolidados_dia ccd
                            where ccd.cod_rubro = '200000000000000'
                              and ccd.fecha = v_fec_actual) porcentaje_operacion,
           b.sal_actual +
           b.sal_actual / (select abs(ccd.sal_mon_loc_ant +
                                      ccd.deb_equ_local - ccd.cre_mon_local) saldo
                             from cb_sal_consolidados_dia ccd
                            where ccd.cod_rubro = '200000000000000'
                              and ccd.fecha = v_fec_actual) monto_porcentaje
    
      from cb_sal_inventarios_his a
      join cb_sal_inventarios_det_his b
        on a.nro_referencia = b.nro_referencia
       and a.fecha = b.fecha
      join ah_cta_certificados c
        on b.nro_cuenta = c.nro_cuenta
      join ge_plz_contables d
        on a.cod_plazo = d.cod_plazo
      join ge_cta_clientes e
        on b.nro_cuenta = e.nro_cuenta
       and e.relacion = 'P'
      join ba_oficinas f
        on a.cod_oficina = f.cod_oficina
      join ge_modalidades g
        on g.cod_modalidad = a.cod_modalidad
      join ba_personas x
        on x.cod_persona = e.cod_persona
     where substr(a.cod_rubro, 6, 3) in (104, 156, 298, 306)
       and ((fug_obt_tas_efe_pizarra(a.cod_modulo,
                                    a.cod_modalidad,
                                    a.cod_moneda,
                                    b.sal_actual,
                                    c.fec_vencimiento - c.fec_apertura,
                                    c.tip_capitalizacion,fug_obt_cod_sub_modalidad(b.nro_cuenta))) * 250 / 100) <
           pas_bcp.fu_obt_tae(fug_obt_val_tasa(a.cod_modulo,
                                               a.cod_modalidad,
                                               a.cod_oficina,
                                               b.nro_cuenta,
                                               a.cod_moneda,
                                               null,
                                               c.tas_personalizada,
                                               c.cod_tasa,
                                               null,
                                               v_fec_actual),
                              c.fec_vencimiento - c.fec_apertura)
       and a.cod_modalidad = 33
       and a.cod_moneda in ('USD')
       and a.fecha = v_fec_actual
       and a.tip_saldo = 'C'
       and to_char(c.fec_apertura, 'MM/YYYY') =
           to_char(v_fec_actual, 'MM/YYYY');


procedure lp_gen_tas_efe_pizarra is 
v_msj                  varchar2(250);
--DYDMR-8519 Incidencia SAU - ITGF - Reprocesos 29/03/2018
PRAGMA AUTONOMOUS_TRANSACTION;

begin
     sql_util.ejecute_dml('truncate table cr_piz_plazos_tmp', v_msj);
     IF v_msj IS NOT NULL THEN
        raise_application_error(-20000, v_msj);
     END IF;

      begin

        insert into cr_piz_plazos_tmp
        select cod_modulo, cod_modalidad, cod_moneda, mto_desde, plz_desde,
               plz_hasta, tas_interes, tas_minima, tas_maxima, tip_capitalizacion,
               tas_efectiva, cod_sub_modalidad, ano, mes
         from cr_piz_plazos_his c
         where c.ano = (select max(x.ano)
                          from cr_piz_plazos_his x
                         where x.cod_modulo = c.cod_modulo
                           and x.cod_modalidad = c.cod_modalidad
                           and x.cod_moneda = c.cod_moneda
                           and x.mto_desde = c.mto_desde
                           and x.PLZ_DESDE = c.plz_desde
                           and x.TIP_CAPITALIZACION = c.tip_capitalizacion
                           and nvl(x.COD_SUB_MODALIDAD, 999) =
                               nvl(c.COD_SUB_MODALIDAD, 999))
           and c.mes = (select max(x.mes)
                          from cr_piz_plazos_his x
                         where x.cod_modulo = c.cod_modulo
                           and x.cod_modalidad = c.cod_modalidad
                           and x.cod_moneda = c.cod_moneda
                           and x.mto_desde = c.mto_desde
                           and x.PLZ_DESDE = c.plz_desde
                           and x.TIP_CAPITALIZACION = c.tip_capitalizacion
                           and nvl(x.COD_SUB_MODALIDAD, 999) =
                               nvl(c.COD_SUB_MODALIDAD, 999)
                           and x.ano = c.ano);
      commit;
      exception
        when others then
             raise_application_error(-20000, 'Error al cr_piz_plazos_tmp '||sqlerrm);
      end;
     


end;


begin
  --DYDMR-8519 Incidencia SAU - ITGF - Reprocesos 29/03/2018
  ---cargar datos de tasa efectiva
  lp_gen_tas_efe_pizarra; 

  v_dir_correo := fug_obt_dir_correo;
  v_name       := 'OPE_SUPERI_' ||
                  to_char(trunc(v_fec_actual), 'yyyy-mm-dd') || '.xls';
  v_file       := utl_file.fopen(v_directorio, v_name, 'W', 32767);

  v_cabecera := 'FEC_APERTURA' || v_separador || 'FECHA' || v_separador ||
                'FECHA OPERACION' || v_separador || 'FECHA VENCIMIENTO' ||
                v_separador || 'COD PERSONA' || v_separador ||
                'NOM COMPLETO' || v_separador || 'COD OFICINA' ||
                v_separador || 'DESCRIPCION OFICINA' || v_separador ||
                'NRO_CUENTA' || v_separador || 'DENOMINACION' ||
                v_separador || 'COD_MODALIDAD' || v_separador ||
                'DESCRIPCION MODALIDAD' || v_separador || 'COD_MONEDA' ||
                v_separador || 'MONTO' || v_separador || 'MONTO_MON_LOCAL' ||
                v_separador || 'TASA_NOMINAL' || v_separador ||
                'TASA EFECTIVA' || v_separador || 'TASA_BASE' ||
                v_separador || 'TASA PIZARRA' || v_separador || 'PLAZO' ||
                v_separador || 'COD_RUBRO' || v_separador ||
                'PORCENTAJE OPERACION' || v_separador || 'MONTO PORCENTAJE' ||
                CHR(13) || CHR(10);
  utl_file.put_line(v_file, v_cabecera);

  for C in c_ope_mar_superi loop
    v_detalles := c.fec_apertura || v_separador || c.fecha || v_separador ||
                  c.fecha_operacion || v_separador || c.fecha_vencimiento ||
                  v_separador || c.cod_persona || v_separador ||
                  c.nom_completo || v_separador || c.cod_oficina ||
                  v_separador || c.descripcion_oficina || v_separador ||
                  c.nro_cuenta || v_separador || c.denominacion_cuenta ||
                  v_separador || c.cod_modalidad || v_separador ||
                  c.descripcion_modalidad || v_separador || c.cod_moneda ||
                  v_separador || c.monto || v_separador ||
                  c.monto_moneda_local || v_separador || c.tasa_nominal ||
                  v_separador || c.tasa_efectiva || v_separador ||
                  c.tasa_Base || v_separador || c.tasa_pizarra ||
                  v_separador || c.plazo || v_separador || c.cod_rubro ||
                  v_separador || c.porcentaje_operacion || v_separador ||
                  c.monto_porcentaje || chr(13) || chr(10);
    utl_file.put_line(v_file, v_detalles);
  end loop;

  utl_file.fclose(v_file);
  commit;

  -- Envio del archivo al directorio FTP
  begin
    declare
      v_conn UTL_TCP.connection;
    begin
      v_conn := utl_ftp.login(g_ip, g_port, g_user, g_pass);
      utl_ftp.ascii(p_conn => v_conn);
      utl_ftp.put(p_conn      => v_conn,
                  p_from_dir  => v_directorio,
                  p_from_file => v_name,
                  p_to_file   => v_directorio_ramail || v_name);
      utl_ftp.logout(v_conn);
      UTL_TCP.close_all_connections;
    exception
      when others then
        UTL_TCP.close_connection(v_conn);
        raise;
    end;
  
  exception
    when others then
      RAISE_APPLICATION_ERROR(-20061,
                              'Error al enviar archivo ' || sqlerrm);
  end;

  --Envio de Email
  begin
    it_mail.mail_attach_xls(v_dir_correo,
                            v_dir_correo_usu,
                            'Operaciones Pasivas Marcadamente Superiores ' ||
                            to_char(trunc(v_fec_actual), 'dd/mm/yyyy'),
                            'Operaciones Pasivas Marcadamente Superiores ' ||
                            to_char(trunc(v_fec_actual), 'dd/mm/yyyy'),
                            v_cabecera || v_detalles,
                            v_name);
  exception
    when others then
      raise_application_error(-20061, 'Error al enviar email ' || sqlerrm);
  end;

exception
  when utl_file.invalid_operation then
    utl_file.fclose(v_file);
    raise_application_error(-20061, 'Operacion invalida ' || sqlerrm);
  when utl_file.invalid_filehandle then
    utl_file.fclose(v_file);
    raise_application_error(-20062, 'Manejador invalido ' || sqlerrm);
  when utl_file.write_error then
    utl_file.fclose(v_file);
    raise_application_error(-20063, 'Error de escritura ' || sqlerrm);
  when utl_file.invalid_mode then
    utl_file.fclose(v_file);
    raise_application_error(-20064, 'Modo invalido ' || sqlerrm);
  when utl_file.internal_error then
    utl_file.fclose(v_file);
    raise_application_error(-20065, 'Internal Error ' || sqlerrm);
end;
/
