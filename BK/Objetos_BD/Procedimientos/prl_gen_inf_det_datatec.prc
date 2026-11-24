CREATE OR REPLACE PROCEDURE IT.PRL_GEN_INF_DET_DATATEC IS
   v_hayDatos     number(4)      := 0;
   v_texto        varchar2(4000) := null;
   v_tas_interes  varchar2(12)   := null;
   v_val_amort    varchar2(12)   := null;
   v_precio       varchar2(20)   := null;
   v_monto        varchar2(20)   := null;
   v_fec_ope      varchar2(10)   := null;
   v_fec_ini      varchar2(10)   := null;
   v_fec_fin      varchar2(10)   := null;
   v_ciudad       varchar2(60)   := null;
   v_fecha        DATE           := pag_cal.FU_OBT_FEC_ACTUAL(7);
   v_bcp_monto    VARCHAR2(100)  := fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS');
   v_usu_datatec  VARCHAR2(100)  := fug_obt_pardinamico('USU_INF_DATATEC');
   v_mon_fuerte   VARCHAR2(3)    := pag_gen.fu_obt_mon_fuerte;
   v_enc_apag     VARCHAR2(100)  := fug_obt_pardinamico('ENC_APA_DATATEC');
   v_cod_per_ent  ge_par_generales.cod_persona%type := fug_obt_per_entidad;
   v_est_modulo   ba_modulos.estado%type;
   v_id_datatec   number(10)     := 0;
   v_tab          varchar2(2)    := CHR(9);
   v_salto        varchar2(2)    := CHR(13)||CHR(10);
   v_file         utl_file.file_type;
   v_nom_archivo  varchar2(15)   := 'tradesxxx.xml';
   --v_directorio   varchar2(100)  := 'MAIL';
   v_directorio   varchar2(100)  := fug_obt_pardinamico('DIR_REP_FTP');
   v_ubicacion    VARCHAR2(100)  := fug_obt_pardinamico('DIR_INF_DATATEC'); 
   g_ip           VARCHAR2(100)  := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
   g_port         VARCHAR2(100)  := '21';
   g_user         VARCHAR2(100)  := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
   g_pass         VARCHAR2(100)  := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
   v_respuesta    varchar2(4000);
   v_hini_ftp     varchar2(8);
   v_hfin_ftp     varchar2(8);

   CURSOR c_mayoristas IS --Cursor para las operaciones liquidadas y no Liquidadas mayores a 10.000 $
      --Compra y Venta (liquidadas y no Liquidadas)
      select s.nro_operacion as id_datatec,
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
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad
        from lc_ope_pendientes s, ba_personas b, ge_clientes c, ba_oficinas d, lc_tip_operaciones g
       where s.cod_persona = b.cod_persona
         and s.fec_operacion = v_fecha
         and s.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and s.cod_tip_operacion = g.cod_tip_operacion
         and b.cod_persona != v_cod_per_ent
         and not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = s.nro_operacion and lc.fec_transaccion = v_fecha)
         and v_bcp_monto <= decode(s.cod_moneda, v_mon_fuerte, s.monto, pag_gen.fu_con_mon_a_moneda(s.cod_moneda, v_mon_fuerte, s.monto, s.cotizacion))
      UNION
      --Arbitraje: se liquida automaticamente
      select a.nro_operacion as id_datatec,
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
             FUE_OBT_VAL_MAX_REFCODES('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad
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
         and b.cod_persona != v_cod_per_ent
         and not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = a.nro_operacion and lc.fec_transaccion = v_fecha)
         and v_bcp_monto <= decode(a.cod_moneda, v_mon_fuerte, a.monto, pag_gen.fu_con_mon_a_moneda(a.cod_moneda, v_mon_fuerte, a.monto, a.cotizacion))
      UNION
      --Forward: no tomamos en cuenta si esta liquidado, solo importa que se pacte la divisa
      select f.nro_operacion as id_datatec,
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
             f.cotizacion as precio,
             f.monto as monto,
             f.cod_moneda,
             'PYG' as cod_mon_contraparte,
             decode(b.tipo,'J','R','F',decode(b.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(b.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             decode(f.tip_liquidacion, 'NDF', 'NON-DELIVERY', 'FDF', 'DELIVERY', 'NON-DELIVERY') as cumplimiento,
             'X' as sis_origen,
             fue_obt_val_max_refcodes('CIU_DATATEC', to_char(d.cod_ciudad)) as ciudad
        from lc_ope_futuras f, ba_personas b, ge_clientes c, ba_oficinas d
       where f.cod_persona = b.cod_persona
         and f.fec_operacion = v_fecha
         and f.cod_persona = c.cod_persona
         and c.cod_oficina = d.cod_oficina
         and b.cod_persona != v_cod_per_ent
         and not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = f.nro_operacion and lc.fec_transaccion = v_fecha)
         and v_bcp_monto <= decode(f.cod_moneda, v_mon_fuerte, f.monto, pag_gen.fu_con_mon_a_moneda(f.cod_moneda, v_mon_fuerte, f.monto, f.cotizacion))
      UNION
      --Operaciones HB: este apartado no tiene operaciones forward
      select gm.nro_documento as id_datatec,
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
             fue_obt_val_max_refcodes('CIU_DATATEC', to_char(o.cod_ciudad)) as ciudad
        from ge_movimientos gm, ba_personas b, ge_clientes i, ba_oficinas o, ge_transacciones t
       where gm.cod_usuario IN ('HOMEBANK', 'HBANK')
         and gm.cod_mod_padre in(7, 9)
         and gm.reversado = 'N'
         and gm.cod_usu_reversion is null
         and gm.cod_tra_padre = 388
         and gm.nro_secuencia in(1, 2)
         and nvl(TRIM(gm.cotizacion), ' ') <> ' '
         and fug_obt_cli_principal(gm.nro_cuenta) = b.cod_persona
         and b.cod_persona = i.cod_persona
         and i.cod_oficina = o.cod_oficina
         and not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = gm.nro_documento) --discriminamos los ya informados
         and not exists (select lc.nro_operacion from lc_ope_pendientes lc where lc.nro_operacion = gm.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_pen_cambios lc where lc.nro_operacion = gm.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_futuras lc where lc.nro_referencia = gm.nro_documento2)
         and gm.cod_modulo = t.cod_modulo (+)
         and gm.cod_modalidad = t.cod_modalidad (+)
         and gm.cod_transaccion = t.cod_transaccion (+)
         and t.tipo in('C', 'D')
         and b.cod_persona != v_cod_per_ent
         and v_bcp_monto <= decode(gm.cod_moneda, v_mon_fuerte, gm.monto, pag_gen.fu_con_mon_a_moneda(gm.cod_moneda, v_mon_fuerte, gm.monto, gm.cotizacion))
         and ((fug_es_empleado(fug_obt_cli_principal(gm.nro_cuenta)) = 'S' and
                  (select count(1) from gv_movimientos b where b.fecha = gm.fecha and b.hora = gm.hora and b.cod_usuario = gm.cod_usuario and b.nro_documento = gm.nro_documento and b.cod_moneda = gm.cod_moneda) = 1
              ) or (
                 ((select count(1) from lc_movimientos_his lm where gm.fecha = lm.fecha and gm.hora = lm.hora and gm.cod_usuario = lm.cod_usuario and gm.nro_documento = lm.nro_documento and gm.cod_moneda != lm.cod_moneda) > 0) or
                 ((select count(1) from cc_movimientos_his cm where gm.fecha = cm.fecha and gm.hora = cm.hora and gm.cod_usuario = cm.cod_usuario and gm.nro_documento = cm.nro_documento and gm.cod_moneda != cm.cod_moneda) > 0) or
                 ((select count(1) from ah_movimientos_his am where gm.fecha = am.fecha and gm.hora = am.hora and gm.cod_usuario = am.cod_usuario and gm.nro_documento = am.nro_documento and gm.cod_moneda != am.cod_moneda) > 0) or
                 ((select count(1) from ge_movimientos g where gm.fecha = g.fecha and gm.hora = g.hora and gm.cod_usuario = g.cod_usuario and gm.nro_documento = g.nro_documento and gm.cod_moneda != g.cod_moneda) > 0)
              ))
      UNION --Referencia del reporte 'LLHOJOPE - Movimientos del dia' (Se obtienen los movimientos de caja y cierre que deben ser informados)
      select g.nro_documento as id_datatec,
             'I' as tip_operacion,
             decode(g.cod_moneda, 'USD', 41, 44) as mercado,
             decode(c.tipo, 'F', 'PARTICULARES', 'J', 'EMPRESA') as origen,
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
             decode(c.tipo,'J','R','F',decode(c.cod_tip_documento,1,'C',2,'P',6,'R','T')) as tip_indentificacion,
             replace(c.nro_documento,'-','') as id_contraparte,
             '' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             nvl(fue_obt_val_max_refcodes('CIU_DATATEC', to_char(o.cod_ciudad)), 'ASU') as ciudad
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
         and c.cod_persona != v_cod_per_ent
         and g.estado IN ('N','H')
         and g.reversado = 'N'
         and g.cod_tip_ope_cambio = l.cod_tip_operacion
         and l.afe_posicion IN ('E','O')
         and g.cod_mad_padre <> 74
         and v_bcp_monto <= decode(g.cod_moneda, v_mon_fuerte, g.monto, pag_gen.fu_con_mon_a_moneda(g.cod_moneda, v_mon_fuerte, g.monto, g.cotizacion))
         and not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = g.nro_documento) --discriminamos los ya informados
         and not exists (select lc.nro_operacion from lc_ope_pendientes lc where lc.fec_operacion = g.fecha and lc.cod_persona = g.cod_persona and lc.monto = g.monto)
         and not exists (select lc.nro_operacion from lc_ope_pen_cambios lc where lc.nro_operacion = g.nro_documento)
         and not exists (select lc.nro_operacion from lc_ope_futuras lc where lc.nro_referencia = g.nro_documento2)
         and not exists (select lc.nro_documento from ge_movimientos lc where lc.fecha = g.fecha and g.cod_persona = nvl(fug_obt_cli_principal(lc.nro_cuenta),'0') and lc.monto = g.monto and lc.cod_tra_padre = 388 and lc.reversado = 'N')
         and g.cod_modulo = t.cod_modulo (+)
         and g.cod_modalidad = t.cod_modalidad (+)
         and g.cod_transaccion = t.cod_transaccion (+)
         and g.fecha = c.fecha(+)
         and g.cod_usuario = c.cod_usuario(+)
         and g.hora = c.hora(+)
         and c.cod_persona = i.cod_persona (+)
         and i.cod_oficina = o.cod_oficina (+);

   CURSOR c_datos IS --Cursor de los datos a enviar
      Select l.id_datatec, l.tip_operacion, l.mercado, l.origen, l.operacion, l.usu_datatec, l.fec_transaccion,
             l.hor_transaccion, l.fec_ini_contrato, l.fec_fin_contrato, l.tip_registro, l.tip_tasa, l.tas_interes,
             l.val_amortizacion, l.precio, l.monto, l.cod_moneda, l.cod_mon_contraparte, l.tip_indentificacion,
             l.id_contraparte, l.observacion, l.cumplimiento, l.sis_origen, l.ciudad
        from lc_inf_datatec l where l.fec_transaccion = v_fecha and l.estado = 'I' and l.observacion is null;

   CURSOR c_informados IS --Cursor de los operaciones ya informadas manualmente
      SELECT p.referencia
        FROM ba_tab_dat_adicionales p
       WHERE p.tab_relacion = 'LC_INF_DATATEC'
         AND p.parametro = 'INFORMADO'
         AND p.val_parametro = 'S'
         AND trunc(p.fec_insercion) = trunc(sysdate)
         AND not exists (select lc.id_datatec from lc_inf_datatec lc where lc.id_datatec = p.referencia and lc.fec_transaccion = v_fecha);

   -- Procedimiento interno para registrar los errores
   PROCEDURE lp_ins_log_error(p_men_error ge_pro_aut_logs.men_error%type)
   IS
     v_proceso NUMBER(3) := 156;
     pragma autonomous_transaction;
   BEGIN
     insert into ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
        values (v_proceso, 'PRL_GEN_INF_DET_DATATEC', sysdate, sysdate, p_men_error);
     commit; -- este commit solo afecta a la transaccion autonoma
   END;

BEGIN
  IF v_enc_apag = 'S' THEN
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(7);
    IF v_est_modulo = 2 THEN -- Solo ejecutar con modulo Abierto.
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
      BEGIN --Antes que nada, verificamos si hay registros informados a datatec manualmente y debemos excluir
        for dato in c_informados loop
          v_id_datatec := dato.referencia;
          insert into lc_inf_datatec (id_datatec, estado, observacion, fec_transaccion)
            values (v_id_datatec, 'E', 'Informado manualmente antes de la carga en IT', v_fecha);
        end loop;
      EXCEPTION
        WHEN OTHERS THEN
          lp_ins_log_error(SUBSTR('Insert de enviados manualmente('||v_id_datatec||'): '||sqlerrm,1,500));
      END;

      FOR dato IN c_mayoristas LOOP --Buscamos los datos e insertamos en la tabla
        BEGIN 
          v_id_datatec := dato.id_datatec;
          insert into lc_inf_datatec (id_datatec, tip_operacion, mercado, origen, operacion, usu_datatec, fec_transaccion,
                      hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                      val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                      id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado)
            values (v_id_datatec, dato.tip_operacion, dato.mercado, dato.origen, dato.operacion, v_usu_datatec, dato.fec_transaccion,
                    dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                    dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                    dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I');
        EXCEPTION
            WHEN OTHERS THEN
               lp_ins_log_error(SUBSTR('Insert a tabla lc_inf_datatec(nro_ope='||v_id_datatec||'): '||sqlerrm,1,500));
        END;
      END LOOP;

      --Verificamos si tenemos registros para enviar
      select count(*) into v_hayDatos from lc_inf_datatec where estado = 'I' and fec_transaccion = v_fecha and observacion is null;

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
        v_texto := '<?xml version="1.0" encoding="Windows-1252"?>'||v_salto||'<transacciones>';
        utl_file.put_line(v_file, v_texto);
        FOR dato IN c_datos LOOP
          begin --Aqui comprobamos si se guardo la ciudad liquidacion desde la pantalla de carga
            SELECT g.val_parametro
              INTO v_ciudad
              FROM ba_tab_dat_adicionales g
             WHERE g.tab_relacion = 'LC_INF_DATATEC'
               AND g.referencia = dato.id_datatec
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
          v_texto := v_tab||'<transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<id>'                        ||dato.id_datatec          ||'</id>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<tipo_operacion>'            ||dato.tip_operacion       ||'</tipo_operacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<mercado>'                   ||dato.mercado             ||'</mercado>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<origen>'                    ||dato.origen              ||'</origen>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<operacion>'                 ||dato.operacion           ||'</operacion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<id_usuario>'                ||dato.usu_datatec         ||'</id_usuario>'||v_salto;
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
          v_texto := v_texto||v_tab||v_tab||'<comentario>'                ||dato.observacion         ||'</comentario>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<cumplimiento>'              ||dato.cumplimiento        ||'</cumplimiento>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<sistema_origen>'            ||dato.sis_origen          ||'</sistema_origen>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<lugar_transaccion>'         ||v_ciudad                 ||'</lugar_transaccion>'||v_salto;
          v_texto := v_texto||v_tab||'</transaccion>';
          utl_file.put_line(v_file, v_texto);
        END LOOP;
        v_texto := '</transacciones>';
        utl_file.put_line(v_file, v_texto);
        --Cerramos el archivo
        UTL_FILE.FCLOSE(v_file);

        --Enviamos el archivo generado al directorio compartido mediante un servidor FTP
        v_hini_ftp  := to_char(sysdate, 'hh24:mi:ss');
        v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                 g_port,
                                                 g_user,
                                                 g_pass,
                                                 v_directorio,
                                                 v_nom_archivo,
                                                 v_ubicacion||v_nom_archivo);
        v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');
        IF v_respuesta <> 'OK' THEN --Error al enviar archivo por ftp. Insertamos el error del envio.
           INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
           VALUES (SYSDATE, v_nom_archivo, v_respuesta, v_hini_ftp, v_hfin_ftp);
           COMMIT;
        ELSIF v_respuesta = 'OK' THEN --Si se envio correctamente, se cambia el estado del registro como Enviado
          FOR dato IN c_datos LOOP
            BEGIN
              update lc_inf_datatec
                 set estado = 'E'
               where id_datatec = dato.id_datatec
                 and estado = 'I';
            EXCEPTION
              when others then
                lp_ins_log_error(SUBSTR('Update de estado: '||sqlerrm,1,500));
            END;
          END LOOP;
        END IF;
        COMMIT;
      END IF;
    END IF;
  END IF;
END;
/

