CREATE OR REPLACE PROCEDURE IT.PRL_GEN_OPE_XML_CAMBIOS
IS
   ----
   v_hayDatos     number(4)      := 0;
   v_texto        varchar2(32000) := null;
   v_tex_largo    varchar2(32000) := null;
   v_tas_interes  varchar2(12)   := null;
   v_val_amort    varchar2(12)   := null;
   v_precio       varchar2(20)   := null;
   v_monto        varchar2(20)   := null;
   v_fec_ope      varchar2(10)   := null;
   v_fec_ini      varchar2(10)   := null;
   v_fec_fin      varchar2(10)   := null;
   v_ciudad       varchar2(60)   := null;
   v_fecha        DATE           := pag_cal.FU_OBT_FEC_ACTUAL(7);
   v_fec_anterior DATE           := pag_cal.fu_obt_fec_anterior(7);
   v_fec_transaccion        DATE;
   v_mon_fuerte   VARCHAR2(3)    := pag_gen.fu_obt_mon_fuerte;
   v_cod_per_ent  ge_par_generales.cod_persona%type := fug_obt_per_entidad;
   v_est_modulo   ba_modulos.estado%type;
   v_id_operacion   number(10)     := 0;
   v_tab          varchar2(2)    := CHR(9);
   v_salto        varchar2(2)    := CHR(13)||CHR(10);
   v_file         utl_file.file_type;
   v_nom_archivo  varchar2(100)   := 'dat_gnb_fus.xml';
   v_nom_archivo_ini  varchar2(100)   := 'dat_gnb_fus_ini.xml';
   v_directorio   varchar2(100)  := 'MAIL';
   v_ubicacion    VARCHAR2(100)  := fug_obt_pardinamico('DIR_INF_ARC_GNB');
   g_ip           VARCHAR2(100)  := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
   g_port         VARCHAR2(100)  := '21';
   g_user         VARCHAR2(100)  := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
   g_pass         VARCHAR2(100)  := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
   v_respuesta    varchar2(4000);
   v_hini_ftp     varchar2(8);
   v_hfin_ftp     varchar2(8);
   v_contador     number(6);
   v_cod_archivo  number(10);
   v_tot_registros number(6);
   v_liquidada     varchar2(1);
   v_nro_operacion varchar2(30);
   v_pos_ini_dia  number(18,2);
   v_pos_ini_for  number(18,2);
   v_informar     varchar2(1);
   v_tip_moneda   varchar2(10);
   v_nom_cliente  varchar2(200);
   v_cod_persona  varchar2(30);
   v_ult_nro      number(18);
   v_env_ini      number(18);
   v_tipo         varchar2(10);
   v_excepcion     varchar2(1);
   --
   v_nom_cli      varchar2(1000);
   v_observacion  varchar2(1000);
   v_cumplimiento  varchar2(1000);
   v_cam_nro_ope   varchar2(1);
   v_nro_ope_pendiente   varchar2(100);
   v_usu_ope_pendiente   varchar2(100);
   --
   v_nro_ope_pen_anu varchar2(100);
   v_cod_usu_pen_anu varchar2(100);
   v_nro_mto_pen_anu GE_MOVIMIENTOS.MONTO%TYPE;
/*
p_tipo
O - Operaciones
I - Ssaldos Iniciales
*/
    CURSOR c_operaciones IS
      --Compra y Venta (liquidadas y no Liquidadas)
      select s.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             decode(s.cod_moneda, 'USD', 41, 44) as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(g.cod_modalidad, 71, 'COMPRA', 72, 'VENTA') as operacion,
             s.fec_operacion as fec_transaccion,
             to_char(s.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             s.cotizacion as precio,
             s.monto as monto,
             s.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             decode(s.liquidado,'S','S','N') liquidada,
             s.usu_insercion usuario, 'SPOT' tipo,
             'N' tipo_ope, s.cta_referencia as nro_cuenta,
             s.usu_insercion as usu_ope, 1 as sel,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'PENDIENTE' as tipo_ope_inf
        from lc_ope_pendientes s, ba_personas b, ge_clientes c, ba_oficinas d, lc_tip_operaciones g
       where s.cod_persona = b.cod_persona
         and s.fec_operacion = v_fecha
         and s.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and s.cod_tip_operacion = g.cod_tip_operacion
         --and b.cod_persona != v_cod_per_ent
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= s.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='S'))
         --
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= s.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'))
      UNION
      --Arbitraje: se liquida automaticamente
      select a.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             47 as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             '' as operacion,
             a.fec_operacion as fec_transaccion,
             to_char(a.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             'TT/TT' as tip_registro,
             '' as tip_tasa,
             a.cotizacion as tas_interes,
             a.monto as val_amortizacion,
             m.cotizacion as precio,
             m.monto as monto,
             decode(a.cod_moneda, 'GS', 'PYG', m.cod_moneda) as cod_moneda,
             decode(m.cod_moneda, 'GS', 'PYG', a.cod_moneda) as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             decode(a.liquidado,'S','S','N') liquidada,
             nvl(a.usu_insercion,m.usu_insercion) usuario, 'SPOT' tipo,
             'N' tipo_ope, a.cta_referencia as nro_cuenta,
             a.usu_insercion as usu_ope, 2 as sel,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'ARBITRAJE' as tipo_ope_inf
        from lc_ope_pen_cambios a, ba_personas b, ge_clientes c, ba_oficinas d, lc_ope_pen_cambios m
       where a.cod_persona = b.cod_persona
         and a.fec_operacion = v_fecha
         and a.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and a.nro_operacion = m.nro_operacion
         and exists (select o.cod_tip_operacion from lc_tip_operaciones o
                     where o.cod_mad_hijo <> 71 and o.cod_tip_operacion = a.cod_tip_operacion) --venta
         and exists (select o.cod_tip_operacion from lc_tip_operaciones o
                     where o.cod_mad_hijo = 71 and o.cod_tip_operacion = m.cod_tip_operacion) --compra
         --and b.cod_persona != v_cod_per_ent
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= a.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='S'))
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= a.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'))
      UNION
      --Forward: se informan las iniciales, cargadas
      select f.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             87 as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(f.cod_mad_transaccion, 71, 'COMPRA', 72, 'VENTA') as operacion,
             f.fec_operacion as fec_transaccion,
             to_char(f.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             f.fec_operacion as fec_ini_contrato,
             f.fec_vencimiento as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             f.cot_vencimiento as precio,--f.cotizacion as precio,
             f.monto as monto,
             f.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             decode(f.tip_liquidacion, 'NDF', 'NON-DELIVERY', 'FDF', 'DELIVERY', 'NON-DELIVERY') as cumplimiento,
             'X' as sis_origen,
             fue_obt_val_max_refcodes('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             decode(f.estado,'L','S','N') liquidada,
             f.usu_insercion usuario, 'FORWARD' tipo,
             'N' tipo_ope,null as nro_cuenta,
             f.usu_insercion as usu_ope, 3 as sel,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'FORWARD' as tipo_ope_inf
        from lc_ope_futuras f, ba_personas b, ge_clientes c, ba_oficinas d
       where f.cod_persona = b.cod_persona
         and f.fec_operacion = v_fecha
         and f.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         --and b.cod_persona != v_cod_per_ent
         and f.estado in ('I','N') --Ingresado/Normal
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= f.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='N'))
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= f.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'))
      UNION
      --Operaciones HB: este apartado no tiene operaciones forward
      select gm.nro_documento as nro_operacion,
             'I' as tip_operacion,
             decode(gm.cod_moneda, 'USD', 41, 44) as mercado, --si viene arbitraje seguramente ya se cargo en el bloque de arriba, sino, se informa como compra/venta
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(t.tipo, 'D', 'COMPRA', 'C', 'VENTA') as operacion,
             gm.fecha as fec_transaccion,
             to_char(gm.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             gm.cotizacion as precio,
             gm.monto as monto,
             gm.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             fue_obt_val_max_refcodes('CIU_DATATEC', to_char(o.cod_ciudad)) as ciudad,
             'S' liquidada,
             gm.usu_insercion usuario, 'SPOT' tipo,
             'N' tipo_ope, gm.nro_cuenta,
              gm.cod_usuario as usu_ope, 4 as sel,
              b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'HB' as tipo_ope_inf
         from ge_movimientos gm, ba_personas b, ge_clientes i, ba_oficinas o, ge_transacciones t
       where (gm.cod_usuario IN ('HOMEBANK', 'HBANK') or gm.cod_usuario like 'HBAN%')
         and gm.cod_mod_padre in(7, 9)
         and gm.reversado = 'N'
         and gm.fecha=v_fecha
         and gm.cod_usu_reversion is null
         and gm.cod_tra_padre = 388
         and gm.nro_secuencia in(1, 2)
         and nvl(TRIM(gm.cotizacion), ' ') <> ' '
         and fug_obt_cli_principal(gm.nro_cuenta) = b.cod_persona
         and b.cod_persona = i.cod_persona
         and i.cod_oficina = o.cod_oficina
         and not exists (select lc.nro_operacion from lc_ope_pendientes lc where lc.nro_operacion = gm.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_pen_cambios lc where lc.nro_operacion = gm.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_futuras lc where lc.nro_referencia = gm.nro_documento2)
         and gm.cod_modulo = t.cod_modulo (+)
         and gm.cod_modalidad = t.cod_modalidad (+)
         and gm.cod_transaccion = t.cod_transaccion (+)
         and t.tipo in('C', 'D')
         --and b.cod_persona != v_cod_per_ent
         and ((fug_es_empleado(fug_obt_cli_principal(gm.nro_cuenta)) = 'S' and
                  (select count(1) from gv_movimientos b where b.fecha = gm.fecha and b.hora = gm.hora and b.cod_usuario = gm.cod_usuario and b.nro_documento = gm.nro_documento and b.cod_moneda = gm.cod_moneda) = 1
              ) or (
                 ((select count(1) from lc_movimientos_his lm where gm.fecha = lm.fecha and gm.hora = lm.hora and gm.cod_usuario = lm.cod_usuario and gm.nro_documento = lm.nro_documento and gm.cod_moneda != lm.cod_moneda) > 0) or
                 ((select count(1) from cc_movimientos_his cm where gm.fecha = cm.fecha and gm.hora = cm.hora and gm.cod_usuario = cm.cod_usuario and gm.nro_documento = cm.nro_documento and gm.cod_moneda != cm.cod_moneda) > 0) or
                 ((select count(1) from ah_movimientos_his am where gm.fecha = am.fecha and gm.hora = am.hora and gm.cod_usuario = am.cod_usuario and gm.nro_documento = am.nro_documento and gm.cod_moneda != am.cod_moneda) > 0) or
                 ((select count(1) from ge_movimientos g where gm.fecha = g.fecha and gm.hora = g.hora and gm.cod_usuario = g.cod_usuario and gm.nro_documento = g.nro_documento and gm.cod_moneda != g.cod_moneda) > 0)
              ))
          --Ok, siempre se envia Liquidado
          and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= gm.nro_documento and lc.fec_transaccion = v_fecha
          and (nvl(lc.liquidado,'N')='S'))
          and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= gm.nro_documento and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'))
      UNION --Referencia del reporte 'LLHOJOPE - Movimientos del día' (Se obtienen los movimientos de caja y cierre que deben ser informados)
       select g.nro_documento as nro_operacion,
             'I' as tip_operacion,
             decode(g.cod_moneda, 'USD', 41, 44) as mercado,
             decode(w.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(t.tipo, 'D', 'COMPRA', 'C', 'VENTA') as operacion,
             g.fecha as fec_transaccion,
             to_char(g.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             g.cotizacion as precio,
             g.monto as monto,
             g.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(w.tipo,'J','R','F',decode(w.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(w.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             nvl(fue_obt_val_max_refcodes('CIU_DATATEC', to_char(o.cod_ciudad)), 'ASU') as ciudad,
             'S' liquidada,
             g.usu_insercion usuario, 'SPOT' tipo,
             'N' tipo_ope, null nro_cuenta,
              g.cod_usuario as usu_ope, 5 as sel,
              w.nro_documento as id_documento,
              nvl(g.COD_PERSONA,c.nro_documento2) cod_persona,
             'CAJA-CIERRE' as tipo_ope_inf
        FROM GE_MOVIMIENTOS g, LC_TIP_OPERACIONES l, GE_TRANSACCIONES t, GE_CLIENTES i, BA_OFICINAS o,
                     (select m.fecha, m.hora, m.cod_usuario, b.tipo,
                             b.cod_tip_documento, b.nro_documento, b.cod_persona, m.nro_documento2
                        from ba_personas b, ge_movimientos m
                       where m.nro_documento2 = b.cod_persona
                         and m.cod_transaccion = 760
                         and m.cod_mod_padre = 7
                         and m.reversado = 'N') c, ba_personas w
       WHERE (g.nro_secuencia = 1 or (g.nro_secuencia = 2  and g.cod_mad_padre in (73,77)))
         and g.monto is not null
         and g.cotizacion is not null
         and g.mto_equ_local is not null
         --and c.cod_persona != v_cod_per_ent
         and g.estado IN ('N','H')
         and g.reversado = 'N'
         and g.cod_tip_ope_cambio = l.cod_tip_operacion
         and l.afe_posicion IN ('E','O')
         and g.cod_mad_padre not in (73,74)--and g.cod_mad_padre <> 74
         and not exists (select lc.nro_operacion from lc_ope_pendientes lc where lc.fec_operacion = g.fecha and lc.cod_persona = g.cod_persona and lc.monto = g.monto)
         and not exists (select lc.nro_operacion from lc_ope_pen_cambios lc where lc.nro_operacion = g.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_futuras lc where lc.nro_referencia = g.nro_documento2)
         and not exists (select lc.nro_documento from ge_movimientos lc where lc.fecha = g.fecha and g.cod_persona = nvl(fug_obt_cli_principal(lc.nro_cuenta),'0') and lc.monto = g.monto and lc.cod_tra_padre = 388 and lc.reversado = 'N')
         and g.cod_modulo = t.cod_modulo (+)
         and g.cod_modalidad = t.cod_modalidad (+)
         and g.cod_transaccion = t.cod_transaccion (+)
         and g.fecha = c.fecha(+)
         and g.fecha=v_fecha
         and g.cod_usuario = c.cod_usuario(+)
         and g.hora = c.hora(+)
         and c.cod_persona = i.cod_persona (+)
         and i.cod_oficina = o.cod_oficina (+)
          and g.cod_persona = w.cod_persona (+)
         --Ok, siempre se envia Liquidado
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= g.nro_documento and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='S'))
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= g.nro_documento and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'));

     --Para arbitraje directo
       CURSOR c_oper_arb_can IS
          select g.nro_documento as nro_operacion,
             'I' as tip_operacion,
             decode(g.cod_moneda, 'USD', 41, 44) as mercado,
             decode(c.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(t.tipo, 'D', 'COMPRA', 'C', 'VENTA') as operacion,
             g.fecha as fec_transaccion,
             to_char(g.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             decode(g.cod_mad_padre,73,'TT/TT','TT/TT') as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             g.cotizacion as precio,
             g.monto as monto,
             g.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(c.tipo,'J','R','F',decode(c.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(c.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             nvl(fue_obt_val_max_refcodes('CIU_DATATEC', to_char(o.cod_ciudad)), 'ASU') as ciudad,
             'S' liquidada,
             g.usu_insercion usuario, 'SPOT' tipo,
             'N' tipo_ope, null nro_cuenta,
              g.cod_usuario as usu_ope,
              g.nro_secuencia,
              c.nro_documento as id_documento,
             c.COD_PERSONA cod_persona,
             'ARBITRAJE DIRECTO' as tipo_ope_inf
        FROM GE_MOVIMIENTOS g, LC_TIP_OPERACIONES l, GE_TRANSACCIONES t, GE_CLIENTES i, BA_OFICINAS o,
                     (select m.fecha, m.hora, m.cod_usuario, b.tipo,
                             b.cod_tip_documento, b.nro_documento, b.cod_persona
                        from ba_personas b, ge_movimientos m
                       where m.nro_documento2 = b.cod_persona
                         and m.cod_transaccion = 760
                         and m.cod_mod_padre = 7
                         and m.reversado = 'N') c
       WHERE (g.nro_secuencia = 1 or (g.nro_secuencia = 2  and g.cod_mad_padre in (73,77)))
         and g.monto is not null
         and g.cotizacion is not null
         and g.mto_equ_local is not null
         --and c.cod_persona != v_cod_per_ent
         and g.estado IN ('N','H')
         and g.reversado = 'N'
         and g.cod_tip_ope_cambio = l.cod_tip_operacion
         and l.afe_posicion IN ('E','O')
         and g.cod_mad_padre =73
         and not exists (select lc.nro_operacion from lc_ope_pendientes lc where lc.fec_operacion = g.fecha and lc.cod_persona = g.cod_persona and lc.monto = g.monto)
         and not exists (select lc.nro_operacion from lc_ope_pen_cambios lc where lc.nro_operacion = g.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_futuras lc where lc.nro_referencia = g.nro_documento2)
         and not exists (select lc.nro_documento from ge_movimientos lc where lc.fecha = g.fecha and g.cod_persona = nvl(fug_obt_cli_principal(lc.nro_cuenta),'0') and lc.monto = g.monto and lc.cod_tra_padre = 388 and lc.reversado = 'N')
         and g.cod_modulo = t.cod_modulo (+)
         and g.cod_modalidad = t.cod_modalidad (+)
         and g.cod_transaccion = t.cod_transaccion (+)
         and g.fecha = c.fecha(+)
         and g.fecha=v_fecha
         and g.cod_usuario = c.cod_usuario(+)
         and g.hora = c.hora(+)
         and c.cod_persona = i.cod_persona (+)
         and i.cod_oficina = o.cod_oficina (+)
         --Ok, siempre se envia Liquidado
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= g.nro_documento and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='S'))
         and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= g.nro_documento and lc.fec_transaccion = v_fecha
         and (nvl(lc.tip_operacion,'N')='A'))
         order by 1, 5;


 -- Informamos los que ya enviamos y se reversaron
 cursor c_reversados is
   select a.Nro_Operacion,a.mercado,a.origen,a.operacion,a.fec_transaccion,a.hor_transaccion,a.fec_ini_contrato,a.fec_fin_contrato,
      a.tip_registro,a.tip_tasa,a.tas_interes,a.val_amortizacion,a.precio,a.monto,a.cod_moneda,a.cod_mon_contraparte, a.tip_indentificacion,
      a.id_contraparte,a.cumplimiento,a.sis_origen,a.ciudad,a.estado,a.liquidado,a.sal_ini_dia,a.usuario, a.tipo,a.sal_ini_for,a.nom_cliente,
      a.observacion, a.nro_cuenta
       from LC_INF_MIGRACION_XML A, ge_movimientos b
          WHERE A.FEC_TRANSACCION=v_fecha
             and a.fec_transaccion= b.fecha
             and a.nro_operacion=b.nro_documento
             and b.nro_secuencia=1
             and b.reversado='S'
             and b.monto>=0
             --Para que sea la misma operacion informada
             AND A.USUARIO= B.COD_USUARIO
             --Solo una vez debe informar reversados
             and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc
                where lc.nro_operacion= a.nro_operacion and lc.fec_transaccion = a.fec_transaccion
                    and lc.tip_operacion='A');


   -- Informamos los que ya se informaron y se eliminaron
 cursor c_eliminados is
    select a.*
       from LC_INF_MIGRACION_XML A
          WHERE A.FEC_TRANSACCION=V_FECHA
           and a.liquidado='N'
           and a.estado='E'
           and (not exists (select 1 from lc_ope_pendientes b
                    where b.fec_operacion=a.fec_transaccion and b.nro_operacion=a.nro_operacion)
           and  not exists (select 1 from lc_ope_pen_cambios b
                    where b.fec_operacion=a.fec_transaccion and b.nro_operacion=a.nro_operacion)
           and   not exists (select 1 from lc_ope_futuras b
                    where b.fec_operacion=a.fec_transaccion and b.nro_operacion=a.nro_operacion)
                )
           and not exists (select 1 from ge_movimientos z
                    where z.fecha=a.fec_transaccion and z.nro_documento=a.nro_operacion and z.reversado='N')

             --Solo una vez debe informar reversados
             and not exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc
                where lc.nro_operacion= a.nro_operacion and lc.fec_transaccion = a.fec_transaccion
                    and lc.tip_operacion='A');


 --Para los que ya informamos y se anularon (Pendientes/ Futuras)
   CURSOR c_a_verificar IS
 --Compra y Venta (liquidadas y no Liquidadas)
      select s.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             decode(s.cod_moneda, 'USD', 41, 44) as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(g.cod_modalidad, 71, 'COMPRA', 72, 'VENTA') as operacion,
             s.fec_operacion as fec_transaccion,
             to_char(s.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             s.cotizacion as precio,
             s.monto as monto,
             s.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             'N' liquidada,
             s.usu_insercion usuario, 'SPOT' tipo,
             'N' tipo_ope, s.cta_referencia as nro_cuenta,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'PENDIENTE VERIFICAR' as tipo_ope_inf
        from lc_ope_pendientes s, ba_personas b, ge_clientes c, ba_oficinas d, lc_tip_operaciones g
       where s.cod_persona = b.cod_persona
         and s.fec_operacion = v_fecha
         and s.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and s.cod_tip_operacion = g.cod_tip_operacion
         --and b.cod_persona != v_cod_per_ent
         and exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= s.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='N') and lc.estado='E' AND LC.TIP_OPERACION IN ('I','M'))
      UNION
      --Arbitraje: se liquida automaticamente
      select a.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             47 as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             '' as operacion,
             a.fec_operacion as fec_transaccion,
             to_char(a.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             'TT/TT' as tip_registro,
             '' as tip_tasa,
             a.cotizacion as tas_interes,
             a.monto as val_amortizacion,
             m.cotizacion as precio,
             m.monto as monto,
             decode(a.cod_moneda, 'GS', 'PYG', m.cod_moneda) as cod_moneda,
             decode(m.cod_moneda, 'GS', 'PYG', a.cod_moneda) as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             decode(a.liquidado,'S','S','N') liquidada,
             nvl(a.usu_insercion,m.usu_insercion) usuario, 'SPOT' tipo,
             'N' tipo_ope,a.cta_referencia as nro_cuenta,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'ARBITRAJE VERIFICAR' as tipo_ope_inf
        from lc_ope_pen_cambios a, ba_personas b, ge_clientes c, ba_oficinas d, lc_ope_pen_cambios m
       where a.cod_persona = b.cod_persona
         and a.fec_operacion = v_fecha
         and a.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and a.nro_operacion = m.nro_operacion
         and exists (select o.cod_tip_operacion from lc_tip_operaciones o
                     where o.cod_mad_hijo <> 71 and o.cod_tip_operacion = a.cod_tip_operacion) --venta
         and exists (select o.cod_tip_operacion from lc_tip_operaciones o
                     where o.cod_mad_hijo = 71 and o.cod_tip_operacion = m.cod_tip_operacion) --compra
         --and b.cod_persona != v_cod_per_ent
         and exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= a.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='N') and lc.estado='E' AND LC.TIP_OPERACION IN ('I','M'))
      UNION
      --Forward: no tomamos en cuenta si esta liquidado, solo importa que se pacte la divisa
      select f.nro_operacion as nro_operacion,
             'I' as tip_operacion,
             87 as mercado,
             decode(b.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
             decode(f.cod_mad_transaccion, 71, 'COMPRA', 72, 'VENTA') as operacion,
             f.fec_operacion as fec_transaccion,
             to_char(f.fec_insercion,'HH24:MI:SS') as hor_transaccion,
             f.fec_operacion as fec_ini_contrato,
             f.fec_vencimiento as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             f.cot_vencimiento as precio,--f.cotizacion as precio,
             f.monto as monto,
             f.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             decode(f.tip_liquidacion, 'NDF', 'NON-DELIVERY', 'FDF', 'DELIVERY', 'NON-DELIVERY') as cumplimiento,
             'X' as sis_origen,
             fue_obt_val_max_refcodes('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad,
             decode(f.estado,'L','S','N') liquidada,
             f.usu_insercion usuario, 'FORWARD' tipo,
             'N' tipo_ope, null as nro_cuenta,
             b.nro_documento as id_documento,
             b.COD_PERSONA cod_persona,
             'FORWARD VERIFICAR' as tipo_ope_inf
        from lc_ope_futuras f, ba_personas b, ge_clientes c, ba_oficinas d
       where f.cod_persona = b.cod_persona
         and f.fec_operacion = v_fecha
         and f.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         --and b.cod_persona != v_cod_per_ent
         and f.estado in ('I','N') --Ingresado/Normal/Liquidado
         and exists (select lc.nro_operacion from LC_INF_MIGRACION_XML lc where lc.nro_operacion= f.nro_operacion and lc.fec_transaccion = v_fecha
         and (nvl(lc.liquidado,'N')='N') and lc.estado='E' AND LC.TIP_OPERACION IN ('I','M'));

   CURSOR c_datos IS --Cursor de los datos a enviar
      Select l.id_operacion, l.nro_operacion,l.tip_operacion, l.mercado, l.origen, l.operacion, /*l.usu_datatec,*/ l.fec_transaccion,
             l.hor_transaccion, l.fec_ini_contrato, l.fec_fin_contrato, l.tip_registro, l.tip_tasa, l.tas_interes,
             l.val_amortizacion, l.precio, l.monto, l.cod_moneda, l.cod_mon_contraparte, l.tip_indentificacion,
             l.id_contraparte, l.observacion, l.cumplimiento, l.sis_origen, l.ciudad,l.sal_ini_dia, l.liquidado,l.usuario, l.tipo, l.sal_ini_for,
             l.nom_cliente,l.nro_cuenta
        from LC_INF_MIGRACION_XML l where l.fec_transaccion = v_fecha and l.estado = 'I' and l.observacion is null
            and l.tip_operacion is not null
            ORDER BY L.NRO_OPERACION,l.tip_operacion;

  CURSOR c_monedas IS
      --Compra y Venta (liquidadas y no Liquidadas)
      select a.*
         from ba_monedas a
           order by a.cod_moneda;

  -- Informamos los que ya enviamos y se reversaron
 cursor c_ope_pen_anu is
   select a.Nro_Operacion,a.mercado,a.origen,a.operacion,a.fec_transaccion,a.hor_transaccion,a.fec_ini_contrato,a.fec_fin_contrato,
      a.tip_registro,a.tip_tasa,a.tas_interes,a.val_amortizacion,a.precio,a.monto,a.cod_moneda,a.cod_mon_contraparte, a.tip_indentificacion,
      a.id_contraparte,a.cumplimiento,a.sis_origen,a.ciudad,a.estado,a.liquidado,a.sal_ini_dia,a.usuario, a.tipo,a.sal_ini_for,a.nom_cliente,
      a.observacion, a.nro_cuenta
       from LC_INF_MIGRACION_XML A
          WHERE A.FEC_TRANSACCION=v_fecha
             and a.nro_operacion= v_nro_ope_pen_anu
             and a.usuario= v_cod_usu_pen_anu
             and a.monto=  v_nro_mto_pen_anu
             and a.liquidado='N';

   -- Procedimiento interno para registrar los errores
   PROCEDURE lp_ins_log_error(p_men_error ge_pro_aut_logs.men_error%type)
   IS
     v_proceso NUMBER(3) := 156;
     pragma autonomous_transaction;
   BEGIN
     insert into ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
        values (v_proceso, 'PRL_GEN_OPE_XML_CAMBIOS', sysdate, sysdate, p_men_error);
     commit; -- este commit solo afecta a la transaccion autonoma
   END;


   -- validacion de cadena xml
   function fp_val_cadena(p_cadena varchar2) return varchar2 is
     v_resultado varchar2(1000);
   BEGIN

       v_resultado:= replace(trim(p_cadena),'&',' ');
       v_resultado:= replace(trim(v_resultado),'<',' ');
       v_resultado:= replace(trim(v_resultado),'>',' ');
       v_resultado:= replace(trim(v_resultado),'''',' ');
       v_resultado:= replace(trim(v_resultado),'"',' ');
       v_resultado := trim(v_resultado);
   return v_resultado;

   END;




   --Para Obtener posición Forward
   FUNCTION FF_OBT_INI_FUTURA (p_moneda  IN VARCHAR2,
                            p_oficina IN NUMBER,
                            p_tipo    IN VARCHAR2
                            )
        RETURN lc_movimientos_his.monto%TYPE IS
        -- Propósito: Obtener la Posición Inicial Futura por moneda y oficina --
        v_ini_futura     lc_movimientos_his.monto%TYPE := 0;
        -- Constantes --
        c_mad_compra     CONSTANT ge_movimientos.cod_mad_padre%TYPE := 71;
        c_mod_padre       CONSTANT ge_movimientos.cod_mod_padre%TYPE := 7;
        c_tra_padre      CONSTANT ge_movimientos.cod_tra_padre%TYPE := 189;
        c_tra_padre2      CONSTANT ge_movimientos.cod_tra_padre%TYPE := 1899;
        -- P_TIPO: Tipo de moneda ME o GS --
          -- ME = Moneda Extranjera
          -- GS = Guaranies
      BEGIN
        IF NVL(p_tipo,'X') = 'ME' THEN  -- Moneda Extranjera
            select sum(decode(cod_mad_padre, c_mad_compra, monto, monto * -1)) total
              into v_ini_futura
              from lc_movimientos_his
             where fecha = fug_obt_fec_anterior(c_mod_padre)
               and cod_mod_padre = c_mod_padre
               and cod_tra_padre in (c_tra_padre,c_tra_padre2)
               and nvl(monto, 0) > 0
               and cod_moneda    = p_moneda
               and cod_oficina   = p_oficina
             group by cod_moneda, cod_oficina;

        ELSIF NVL(p_tipo,'X') = 'GS' THEN  -- Moneda Local Guaranies
            select sum(fug_obt_cotizacion(cod_moneda, fug_obt_fec_anterior(c_mod_padre)) *
                      (decode(cod_mad_padre, c_mad_compra, monto, monto * -1))) tot_gs
              into v_ini_futura
              from lc_movimientos_his
             where fecha = fug_obt_fec_anterior(c_mod_padre)
               and cod_mod_padre = c_mod_padre
               and cod_tra_padre in (c_tra_padre,c_tra_padre2)
               and nvl(monto, 0) > 0
               and cod_moneda    = p_moneda
               and cod_oficina   = p_oficina
             group by cod_moneda, cod_oficina;
        END IF;

        RETURN v_ini_futura;
      EXCEPTION
        WHEN OTHERS THEN
          RETURN 0;
      END;

--Anulación de operaciones BBVA
PROCEDURE  pr_ins_reg_anulacion
 (P_nro_ope_pendiente IN varchar2
 ,P_COD_USUARIO IN varchar2
 ,P_MONTO IN GE_MOVIMIENTOS.MONTO%TYPE)
 IS
--

BEGIN
   v_nro_ope_pen_anu:=null;
   v_cod_usu_pen_anu:=null;
   v_nro_mto_pen_anu:=0;
   --
   v_nro_ope_pen_anu:=P_nro_ope_pendiente;
   v_cod_usu_pen_anu:=P_COD_USUARIO;
   v_nro_mto_pen_anu:=P_MONTO;
     --Cargamos los reversados, de las operaciones ya informados en el día
         FOR rev IN c_ope_pen_anu LOOP --Buscamos los datos e insertamos en la tabla
                  BEGIN
                     v_id_operacion:= NULL;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente, nro_cuenta)
                      values (v_id_operacion,rev.nro_operacion,'A', rev.mercado, rev.origen, rev.operacion,  rev.fec_transaccion,
                                rev.hor_transaccion, rev.fec_ini_contrato, rev.fec_fin_contrato, rev.tip_registro, rev.tip_tasa, rev.tas_interes,
                                rev.val_amortizacion, rev.precio, rev.monto, rev.cod_moneda, rev.cod_mon_contraparte, rev.tip_indentificacion,
                                rev.id_contraparte, rev.observacion, rev.cumplimiento, rev.sis_origen, rev.ciudad,'I',rev.sal_ini_dia,
                                rev.liquidado, rev.Usuario,rev.Tipo, rev.sal_ini_for,
                                rev.nom_cliente, rev.nro_cuenta);
                       --commit;
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML ANU BBVA(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;

      END LOOP;


END;



/* INICIO DE PROCESO PRINCIPAL*/
BEGIN
    Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; end;
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(7);
    v_tipo:='O';
    if UPPER(v_tipo) not in ('O','I') THEN
      lp_ins_log_error(SUBSTR('Error-Tipo Solo puede ser O- Operaciones/ I- Saldos Iniciales',1,500));
    END IF;
    --v_tipo:= P_TIPO;

    IF UPPER(v_tipo) ='O' THEN
            --No generar feriados -porque esta como Repetitivo el proceso
            if trunc(v_fecha) <> trunc(sysdate) then
                  --para que no siga
                 v_tipo:='W';

             end if;

    END IF;

   --Operaciones
IF v_tipo='O' THEN
    IF v_est_modulo = 2 THEN -- Solo ejecutar con modulo Abierto.
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
         FOR dato IN c_operaciones LOOP --Buscamos los datos e insertamos en la tabla
           v_informar:='N';
           v_pos_ini_for:=0;
           v_pos_ini_dia:= 0;
           v_tip_moneda:= null;
           v_excepcion:='N';

           if pag_gen.FU_OBT_MON_LOCAL = dato.cod_moneda then
              v_tip_moneda:= 'GS';
           else
             v_tip_moneda:= 'ME';
           end if;
                 --Si viene como liquidada='S' es porque no se informó aún asi.
           if nvl(dato.liquidada,'N')='S' then
               v_informar:='S';

               if upper(dato.tipo)='SPOT' and dato.tip_operacion='I' then
                  --Verificamos si no se informó antes
                  begin
                     select 'N'
                       into v_excepcion
                         from LC_INF_MIGRACION_XML lc
                           where lc.nro_operacion= dato.nro_operacion
                              and TRUNC(lc.fec_transaccion) = TRUNC(dato.fec_transaccion)
                                 and (nvl(lc.liquidado,'N')='N')
                                 and lc.hor_transaccion= dato.hor_transaccion
                                 and lc.tip_operacion='I' ;
                    exception
                      when no_data_found then
                        v_excepcion:='S';
                    end;
               end if;

            else
            --Verificamos, si liquidado='N', si ya no se informó con el mismo estado antes
                begin
                   select 'N'
                     into v_informar
                       from LC_INF_MIGRACION_XML lc
                         where lc.nro_operacion= dato.nro_operacion
                            and lc.fec_transaccion = dato.fec_transaccion
                               and (nvl(lc.liquidado,'N')='N')
                               and lc.hor_transaccion= dato.hor_transaccion
                               and lc.tip_operacion IN ('I','L') ;
                  exception
                    when no_data_found then
                      v_informar:='S';
                  end;
            end if;

            --Para nombre de cliente
            v_nom_cliente :=null;
            v_cod_persona :=null;
            if dato.iD_DOCUMENTO is not null then
              v_nom_cliente := fue_obt_nom_per_documento(/*dato.id_contraparte*/dato.iD_DOCUMENTO,v_cod_persona);
            end if;
            if v_nom_cliente is null then
                if dato.cod_persona is not null then
                    v_cod_persona:= dato.cod_persona;
                    v_nom_cliente := fue_obt_nom_persona(v_cod_persona);
                    v_cod_persona :=null;
                else
                  v_cod_persona :=null;
                  v_nom_cliente:= null;
                end if;
            end if;

            v_fec_transaccion:= null;
            v_fec_transaccion:= dato.fec_transaccion;

           --Si solo vamos a informar como Liquidado='S', primero informamos como Liquidado='N', para BT
           if upper(dato.liquidada) ='S' and v_excepcion= 'S' and nvl(v_informar,'N') ='S'  then
                BEGIN
                      -- Ajuste para operaciones BBVA en usd contra cuenta contable
                      -- si es operacion normal y no es BBVA
                      v_cam_nro_ope:='N';
                      v_nro_ope_pendiente:= null;
                      v_usu_ope_pendiente:= null;

                       if dato.tipo_ope_inf='CAJA-CIERRE' and dato.cod_persona <> '11198'  then
                             begin
                               --buscamos en ope pendientes
                                select 'S',a.nro_operacion,upper(a.usu_insercion)
                                  into v_cam_nro_ope,v_nro_ope_pendiente,v_usu_ope_pendiente
                                   from lc_ope_pendientes a
                                     where a.fec_operacion= v_fecha
                                       and a.liquidado='S'
                                       and a.cod_persona = 11198
                                       and upper(a.cod_usu_liquidacion)=upper(dato.usuario) -- si es el usuario que liquida
                                       and a.cod_moneda= dato.cod_moneda  --moneda
                                       and a.monto = dato.monto   --monto
                                       and a.cotizacion= dato.precio  --cotizacion
                                       and a.nro_operacion <> dato.nro_operacion -- Que los nros de operacion no coincidan
                                       and a.ope_homebanking='N';     -- no es Hb
                            exception
                              when no_data_found then
                                v_cam_nro_ope:='N';
                              when others then
                                v_cam_nro_ope:='N';
                            end;

                            if v_cam_nro_ope='S' then
                               --Buscamos si ya se envió para validar doble

                                 v_cam_nro_ope:='N';
                                      begin

                                          select 'S'
                                            into v_cam_nro_ope
                                             from LC_INF_MIGRACION_XML a
                                               where a.fec_transaccion = v_fecha
                                                 and a.liquidado='N' -- que se informó como no liquidado
                                                 and upper(a.usuario) = upper(v_usu_ope_pendiente) --mismo usuario
                                                 and a.nro_operacion= v_nro_ope_pendiente --mismo nro de operacion
                                                 and a.monto= dato.monto --mismo monto
                                                 and a.cod_moneda=  dato.cod_moneda --misma moneda
                                                 and a.id_contraparte='800229550'; --que sea BBVA lo que se anula;
                                      exception
                                        when no_data_found then
                                          v_cam_nro_ope:='N';
                                        when others then
                                          v_cam_nro_ope:='N';
                                      end;
                                  --enviamos la anulacion del anterior
                                  if v_cam_nro_ope='S' then
                                     pr_ins_reg_anulacion(v_nro_ope_pendiente,v_usu_ope_pendiente,dato.monto);
                                  end if;


                            end if;


                        end if;


                         v_nro_operacion:= null;
                         v_nro_operacion:= dato.nro_operacion;
                         v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                        insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                    hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                    val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                    id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                    nom_cliente,nro_cuenta)
                          values (v_id_operacion,v_nro_operacion,'L'/*dato.tip_operacion*/, dato.mercado, dato.origen, dato.operacion,  v_fec_transaccion,
                                  dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                                  dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                                  dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I',v_pos_ini_dia, 'N',
                                  dato.usuario, dato.tipo,v_pos_ini_for,
                                  v_nom_cliente, dato.nro_cuenta);
                      EXCEPTION
                          WHEN OTHERS THEN
                              lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML_EXC(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                      END;
           end if;




        if  nvl(v_informar,'N') ='S' then
                  BEGIN
                     v_nro_operacion:= null;
                     v_nro_operacion:= dato.nro_operacion;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente,nro_cuenta)
                      values (v_id_operacion,v_nro_operacion,dato.tip_operacion, dato.mercado, dato.origen, dato.operacion,  v_fec_transaccion,
                              dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                              dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                              dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I',v_pos_ini_dia, nvl(dato.liquidada,'S'),
                              dato.usuario, dato.tipo,v_pos_ini_for,
                              v_nom_cliente, dato.nro_cuenta);
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;
        end if;

      END LOOP;
      --Para Canje y arbitraje directo
       FOR dato IN c_oper_arb_can LOOP --Buscamos los datos e insertamos en la tabla
           v_informar:='N';
           v_tip_moneda:= null;
           v_excepcion:='N';
        if dato.nro_secuencia= 1 then
           if pag_gen.FU_OBT_MON_LOCAL = dato.cod_moneda then
              v_tip_moneda:= 'GS';
           else
             v_tip_moneda:= 'ME';
           end if;

             --Para nombre de cliente
            v_nom_cliente :=null;
            v_cod_persona :=null;
            if dato.iD_DOCUMENTO is not null then
              v_nom_cliente := fue_obt_nom_per_documento(/*dato.id_contraparte*/dato.iD_DOCUMENTO,v_cod_persona);
            end if;
            if v_nom_cliente is null then
                if dato.cod_persona is not null then
                    v_cod_persona:= dato.cod_persona;
                    v_nom_cliente := fue_obt_nom_persona(v_cod_persona);
                    v_cod_persona :=null;
                else
                  v_cod_persona :=null;
                  v_nom_cliente:= null;
                end if;
            end if;



            v_fec_transaccion:= null;
            v_fec_transaccion:= dato.fec_transaccion;


           --Si solo vamos a informar como Liquidado='S', primero informamos como Liquidado='N', para BT
           --Cargamos Liquidado 'N'
                BEGIN
                         v_nro_operacion:= null;
                         v_nro_operacion:= dato.nro_operacion;
                         v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                        insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                    hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                    val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                    id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                    nom_cliente,nro_cuenta)
                          values (v_id_operacion,v_nro_operacion,'L'/*dato.tip_operacion*/, dato.mercado, dato.origen, null,  v_fec_transaccion,
                                  dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                                  dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                                  dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I',v_pos_ini_dia, 'N',
                                  dato.usuario, dato.tipo,v_pos_ini_for,
                                  v_nom_cliente, dato.nro_cuenta);
                      EXCEPTION
                          WHEN OTHERS THEN
                              lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML_EXC(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                      END;
            --Cargamos Liquidado S
                  BEGIN
                     v_nro_operacion:= null;
                     v_nro_operacion:= dato.nro_operacion;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente,nro_cuenta)
                      values (v_id_operacion,v_nro_operacion,dato.tip_operacion, dato.mercado, dato.origen, null,  v_fec_transaccion,
                              dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                              dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                              dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I',v_pos_ini_dia, nvl(dato.liquidada,'S'),
                              dato.usuario, dato.tipo,v_pos_ini_for,
                              v_nom_cliente, dato.nro_cuenta);
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;
          else
            --Hacemos Update
            update LC_INF_MIGRACION_XML s
               set s.tas_interes= dato.precio,
                   s.val_amortizacion= dato.monto,
                   s.cod_mon_contraparte= dato.cod_moneda
                 where s.nro_operacion=dato.nro_operacion
                   and s.fec_transaccion= dato.fec_transaccion;
          end if;


      END LOOP;





      --Cargamos los reversados, de las operaciones ya informados en el día
         FOR rev IN c_reversados LOOP --Buscamos los datos e insertamos en la tabla
                  BEGIN
                     v_id_operacion:= NULL;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente, nro_cuenta)
                      values (v_id_operacion,rev.nro_operacion,'A', rev.mercado, rev.origen, rev.operacion,  rev.fec_transaccion,
                                rev.hor_transaccion, rev.fec_ini_contrato, rev.fec_fin_contrato, rev.tip_registro, rev.tip_tasa, rev.tas_interes,
                                rev.val_amortizacion, rev.precio, rev.monto, rev.cod_moneda, rev.cod_mon_contraparte, rev.tip_indentificacion,
                                rev.id_contraparte, rev.observacion, rev.cumplimiento, rev.sis_origen, rev.ciudad,'I',rev.sal_ini_dia,
                                rev.liquidado, rev.Usuario,rev.Tipo, rev.sal_ini_for,
                                rev.nom_cliente, rev.nro_cuenta);
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML REV(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;

      END LOOP;
         --Ya informados, no liquidados y eliminados
         FOR rev IN c_eliminados LOOP --Buscamos los datos e insertamos en la tabla
                  BEGIN
                     v_id_operacion:= NULL;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente, Nro_Cuenta)
                      values (v_id_operacion,rev.nro_operacion,'A', rev.mercado, rev.origen, rev.operacion,  rev.fec_transaccion,
                                rev.hor_transaccion, rev.fec_ini_contrato, rev.fec_fin_contrato, rev.tip_registro, rev.tip_tasa, rev.tas_interes,
                                rev.val_amortizacion, rev.precio, rev.monto, rev.cod_moneda, rev.cod_mon_contraparte, rev.tip_indentificacion,
                                rev.id_contraparte, rev.observacion, rev.cumplimiento, rev.sis_origen, rev.ciudad,'I',rev.sal_ini_dia,
                                rev.liquidado, rev.Usuario,rev.Tipo, rev.sal_ini_for,
                                rev.nom_cliente, rev.nro_cuenta);
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML eli(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;

      END LOOP;

  --Verificamos los que ya enviamos , por si se borraron o ajustaron
  FOR dato IN c_a_verificar LOOP --Buscamos los datos e insertamos en la tabla
           v_informar:='N';
           v_pos_ini_for:=0;
           v_pos_ini_dia:= 0;
           v_tip_moneda:= null;

           if pag_gen.FU_OBT_MON_LOCAL = dato.cod_moneda then
              v_tip_moneda:= 'GS';
           else
             v_tip_moneda:= 'ME';
           end if;
           --Buscamos el ultimo registro para comparar
            v_ult_nro:= null;
            select max(z.id_operacion)
             into v_ult_nro
               from LC_INF_MIGRACION_XML z
                 where z.nro_operacion= dato.nro_operacion
                            and z.fec_transaccion = dato.fec_transaccion;

            --Verificamos, si liquidado='N', si ya no se informó con el mismo estado antes
                begin
                   select 'S'
                     into v_informar
                       from LC_INF_MIGRACION_XML lc
                         where lc.nro_operacion= dato.nro_operacion
                            and lc.fec_transaccion = dato.fec_transaccion
                            and lc.id_operacion= v_ult_nro
                               and (nvl(lc.liquidado,'N')='N')
                               and lc.tip_operacion in ('I','L')
                               and lc.fec_transaccion= dato.fec_transaccion
                               and lc.hor_transaccion=dato.hor_transaccion
                               and (nvl(lc.monto,0) <> nvl(dato.monto,0) or nvl(lc.precio,0) <> nvl(dato.precio,0)
                               or nvl(lc.cod_moneda,0) <> nvl(dato.cod_moneda,0)
                               or nvl(lc.cod_mon_contraparte,0) <> nvl(dato.cod_mon_contraparte,0)
                               or nvl(lc.id_contraparte,0) <> nvl(dato.id_contraparte,0)
                               );
                  exception
                    when no_data_found then
                      v_informar:='N';
                    when too_many_rows then
                      v_informar:='S';
                  end;


              --Para nombre de cliente
            v_nom_cliente :=null;
            v_cod_persona :=null;
            if dato.iD_DOCUMENTO is not null then
              v_nom_cliente := fue_obt_nom_per_documento(/*dato.id_contraparte*/dato.iD_DOCUMENTO,v_cod_persona);
            end if;
            if v_nom_cliente is null then
                if dato.cod_persona is not null then
                    v_cod_persona:= dato.cod_persona;
                    v_nom_cliente := fue_obt_nom_persona(v_cod_persona);
                    v_cod_persona :=null;
                else
                  v_cod_persona :=null;
                  v_nom_cliente:= null;
                end if;
            end if;


            v_fec_transaccion:= null;
            v_fec_transaccion:= dato.fec_transaccion;

        if  nvl(v_informar,'N') ='S' then
                  --Inertamos el nuevo , con los nuevos datos
                  BEGIN
                     v_nro_operacion:= null;
                     v_nro_operacion:= dato.nro_operacion;
                     v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                    insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,tip_operacion, mercado, origen, operacion,  fec_transaccion,
                                hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                                val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                                id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado,sal_ini_dia,liquidado, Usuario,Tipo, sal_ini_for,
                                nom_cliente,nro_cuenta)
                      values (v_id_operacion,v_nro_operacion,'M', dato.mercado, dato.origen, dato.operacion,  v_fec_transaccion,
                              dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                              dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                              dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I',v_pos_ini_dia, nvl(dato.liquidada,'S'),
                              dato.usuario, dato.tipo,v_pos_ini_for,
                              v_nom_cliente, dato.nro_cuenta);
                  EXCEPTION
                      WHEN OTHERS THEN
                          lp_ins_log_error(SUBSTR('Insert a tabla LC_INF_MIGRACION_XML nuevo (nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                  END;
        end if;

      END LOOP;


      --Verificamos si tenemos registros para envíar
      select count(*) into v_hayDatos from LC_INF_MIGRACION_XML where estado = 'I' and fec_transaccion = v_fecha and observacion is null;
      -- dbms_output.put_line('Hay Datos: '||v_hayDatos);
      IF v_hayDatos > 0 THEN
        BEGIN --Abrimos el archivo
           IF UTL_FILE.IS_OPEN (v_file) THEN
               UTL_FILE.FCLOSE (v_file);
           End IF;
           v_file := UTL_FILE.FOPEN(v_directorio, v_nom_archivo,'W',32767) ;

        EXCEPTION
          when others then
            lp_ins_log_error(SUBSTR('No se pudo abrir el archivo: '||sqlerrm,1,500));
        END;
        --Inicia carga de archivo
        v_texto := null;
        v_tex_largo := null;
        v_texto := '<?xml version="1.0" encoding="Windows-1252"?>'||v_salto||'<transacciones>';
        v_tex_largo := v_tex_largo||v_texto;
        utl_file.put_line(v_file, v_texto);
        v_contador := 0;
        v_cod_archivo := 0;
        FOR dato IN c_datos LOOP
          v_liquidada:=null;
          v_liquidada := dato.liquidado;
          v_contador := v_contador + 1;
          v_cod_archivo := v_cod_archivo + 1;
          if v_contador > 1 then
             v_texto := null;
             v_tex_largo := null;
          end if;
          --if v_contador <= 10 then
          begin --Aqui comprobamos si se guardo la ciudad liquidacion desde la pantalla de carga
            SELECT g.val_parametro
              INTO v_ciudad
              FROM ba_tab_dat_adicionales g
             WHERE g.tab_relacion = 'LC_INF_DATATEC'
               AND g.referencia = dato.id_operacion
               AND g.parametro = 'LIQ_CIUDAD';
          exception
            when others then --si no, continuamos enviando el usu_modificacion
              v_ciudad := dato.ciudad;
          end;
          v_tas_interes := ltrim(nvl(to_char(dato.tas_interes,'9999.99'),''));
          v_val_amort   := ltrim(nvl(to_char(dato.val_amortizacion,'999999999.99'),''));
          v_precio      := ltrim(to_char(dato.precio,'9999.9999'));
          v_monto       := ltrim(to_char(dato.monto,'999999999.99'));
          v_fec_ope     := to_char(dato.fec_transaccion,'YYYY-MM-DD');
          v_fec_ini     := nvl(to_char(dato.fec_ini_contrato,'YYYY-MM-DD'),'');
          v_fec_fin     := nvl(to_char(dato.fec_fin_contrato,'YYYY-MM-DD'),'');


          v_nom_cli:=null;
          v_observacion:=null;
          v_cumplimiento:=null;

          v_nom_cli:= trim(fp_val_cadena(dato.nom_cliente));
          v_observacion:= trim(fp_val_cadena(dato.observacion)) ;
          v_cumplimiento:=trim(fp_val_cadena(dato.cumplimiento)) ;

          v_texto := v_tab||'<transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<id>'                        ||dato.nro_operacion       ||'</id>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo_operacion>'            ||dato.tip_operacion       ||'</tipo_operacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<mercado>'                   ||dato.mercado             ||'</mercado>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<origen>'                    ||dato.origen              ||'</origen>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<operacion>'                 ||dato.operacion           ||'</operacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<id_usuario>'                ||dato.usuario             ||'</id_usuario>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<fecha_transaccion>'         ||v_fec_ope                ||'</fecha_transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<hora_transaccion>'          ||dato.hor_transaccion     ||'</hora_transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<fecha_inicio_contrato>'     ||v_fec_ini                ||'</fecha_inicio_contrato>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<fecha_fin_contrato>'        ||v_fec_fin                ||'</fecha_fin_contrato>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo_registro>'             ||dato.tip_registro        ||'</tipo_registro>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo_tasa_1>'               ||dato.tip_tasa            ||'</tipo_tasa_1>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tasa_interes>'              ||v_tas_interes            ||'</tasa_interes>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<valor_amortizacion>'        ||v_val_amort              ||'</valor_amortizacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<precio>'                    ||v_precio                 ||'</precio>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<monto_transado>'            ||v_monto                  ||'</monto_transado>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<moneda_monto>'              ||dato.cod_moneda          ||'</moneda_monto>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<moneda_contraparte>'        ||dato.cod_mon_contraparte ||'</moneda_contraparte>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo_identificacion>'       ||dato.tip_indentificacion ||'</tipo_identificacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<identificacion_contraparte>'||dato.id_contraparte      ||'</identificacion_contraparte>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<comentario>'                ||v_observacion            ||'</comentario>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<cumplimiento>'              ||v_cumplimiento           ||'</cumplimiento>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<sistema_origen>'            ||dato.sis_origen          ||'</sistema_origen>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<lugar_transaccion>'         ||v_ciudad                 ||'</lugar_transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<liquidada>'                 ||v_liquidada              ||'</liquidada>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo>'                      ||dato.tipo                ||'</tipo>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<nombre_cliente>'            ||v_nom_cli                ||'</nombre_cliente>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<nro_cuenta>'                ||dato.nro_cuenta          ||'</nro_cuenta>'||v_salto;
          v_texto := v_texto||v_tab||'</transaccion>';
          utl_file.put_line(v_file, v_texto);
          v_tex_largo := v_tex_largo||v_texto;
          -------

        END LOOP;
        -------
        v_texto := null;
        v_tex_largo := null;
        v_texto := '</transacciones>';
        v_tex_largo := v_tex_largo||v_texto;
        v_cod_archivo := v_cod_archivo + 1;
        utl_file.put_line(v_file, v_texto);
        --Cerramos el archivo
        UTL_FILE.FCLOSE(v_file);

        --Enviamos el archivo generado al directorio compartido mediante un servidor FTP
       -- dbms_output.put_line('ip: '||g_ip||' user:'||g_user||' pas:'||g_pass|| ' ubi:'||v_ubicacion||' nom_arch:'||v_nom_archivo|| ' Ubi_Nom:'||v_ubicacion||v_nom_archivo);
        v_hini_ftp  := to_char(sysdate, 'hh24:mi:ss');
        v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                 g_port,
                                                 g_user,
                                                 g_pass,
                                                 v_directorio,
                                                 v_nom_archivo,
                                                 v_ubicacion||v_nom_archivo);

        v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');
       -- dbms_output.put_line('Resp:'||v_respuesta );
       IF v_respuesta <> 'OK' THEN --Error al enviar archivo por ftp. Insertamos el error del envio.
           INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
           VALUES (SYSDATE, v_nom_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
           COMMIT;

       ELSIF v_respuesta = 'OK' THEN --Si se envió correctamente, se cambia el estado del registro como Enviado*/

          FOR dato IN c_datos LOOP
            BEGIN
              update LC_INF_MIGRACION_XML s
                 set s.estado = 'E'
               where s.id_operacion = dato.id_operacion
                 and s.liquidado = dato.liquidado
                 and s.hor_transaccion= dato.hor_transaccion
                 and s.estado = 'I';
                 commit;
            EXCEPTION
              when others then
                lp_ins_log_error(SUBSTR('Update de estado: '||sqlerrm,1,500));
            END;
          END LOOP;
        END IF;
        COMMIT;
      END IF;
    END IF;


end if;

END;
/

