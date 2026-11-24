CREATE OR REPLACE PROCEDURE IT.PRL_GEN_INF_CON_DATATEC IS
   v_hayDatos     number(4)      := 0;
   v_yaInformado  number(4)      := 0;
   v_texto        varchar2(4000) := null;
   v_precio       varchar2(20)   := null;
   v_monto        varchar2(20)   := null;
   v_fec_ope      varchar2(10)   := null;
   v_fecha        DATE           := pag_cal.FU_OBT_FEC_ACTUAL(7);
   v_bcp_monto    VARCHAR2(100)  := fug_obt_pardinamico('BCP_MTO_INF_CAMBIOS');
   v_usu_datatec  VARCHAR2(100)  := fug_obt_pardinamico('USU_INF_DATATEC');
   v_mon_fuerte   VARCHAR2(3)    := pag_gen.fu_obt_mon_fuerte;
   v_mon_local    VARCHAR2(3)    := pag_gen.fu_obt_mon_local;
   v_enc_apag     VARCHAR2(100)  := fug_obt_pardinamico('ENC_APA_DATATEC');
   v_est_modulo   ba_modulos.estado%type;
   v_id_consol    NUMBER(10)     := 0;
   v_tab          varchar2(2)    := CHR(9);
   v_salto        varchar2(2)    := CHR(13)||CHR(10);
   v_file         utl_file.file_type;
   v_nom_archivo  varchar2(15)   := 'traconxxx.xml';
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

   CURSOR c_minoristas IS --Cursor del consolidado
      Select 'I' as tip_operacion,
             41 as mercado,
             'PARTICULARES' as origen,
             decode(m.tipo,'D','COMPRA','C','VENTA') as operacion,
             v_fecha as fec_transaccion,
             to_char(sysdate,'HH24:MI:SS') as hor_transaccion,
             null as fec_ini_contrato,
             null as fec_fin_contrato,
             '' as tip_registro,
             '' as tip_tasa,
             null as tas_interes,
             null as val_amortizacion,
             decode(m.tipo,'D',(sum(m.mto_compra_gs)/sum(m.mto_compra_usd)),
                           'C',(sum(m.mto_venta_gs)/sum(m.mto_venta_usd)),0) as precio,
             decode(m.tipo,'D',nvl(sum(m.mto_compra_usd),0),
                           'C',nvl(sum(m.mto_venta_usd),0),0) as monto,
             'USD' as cod_moneda,
             'PYG' as cod_mon_contraparte,
             'C' as tip_indentificacion,
             '0000001' as id_contraparte,
             'Consolidado Minorista' as observacion,
             '' as cumplimiento,
             'X' as sis_origen,
             'ASU' as ciudad
        from (--Referencia del 1er select: reporte 'LLDICOVE - Compra Venta Dolares' (Consolidado sin operaciones web, segun Mesa de Cambios)
              select decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(g.cod_moneda,v_mon_fuerte,nvl(g.monto,0),g.cotizacion),0) mto_compra_usd,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(g.cod_moneda,v_mon_fuerte,nvl(g.monto,0),g.cotizacion),0) mto_venta_usd,
                     decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(g.cod_moneda,v_mon_local,nvl(g.monto,0),g.cotizacion),0) mto_compra_gs,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(g.cod_moneda,v_mon_local,nvl(g.monto,0),g.cotizacion),0) mto_venta_gs,
                     t.tipo, g.nro_documento
                from GE_MOVIMIENTOS_ant g, LC_TIP_OPERACIONES lo, GE_TRANSACCIONES t
               where ((g.cod_mad_padre in (71,72) and g.nro_secuencia = 1 and g.cod_ref_cambio <> 76)
                       or (g.cod_mad_padre = 76 and g.nro_secuencia = 1)
                       or (g.cod_mad_padre in (73) and g.nro_secuencia in (1,2)) )
                 and g.monto is not null
                 and g.cotizacion is not null
                 and g.mto_equ_local is not null
                 and ful_cli_ope_cambios(decode(g.cod_mad_padre, 76, g.cod_persona, to_char(g.nro_documento2)),
                     g.monto,g.cod_moneda,g.fecha,'N',g.cod_mad_padre) = 8 --corresponde a consolidado, menores al monto parametrizado de datatec
                 and g.reversado = 'N'
                 and g.cod_tip_ope_cambio = lo.cod_tip_operacion
                 and ((afe_posicion IN ('E', 'O') AND g.cod_mad_padre <> 76) OR (g.cod_mad_padre = 76))
                 and cod_mad_padre <> 74
                 and g.cod_modulo = t.cod_modulo (+)
                 and g.cod_modalidad = t.cod_modalidad (+)
                 and g.cod_transaccion = t.cod_transaccion (+)
              union
              --Referencia del 2do select: consulta dinamica 'TRA_MON_HB - TRANSFERENCIAS REALIZADAS ENTRE DIFERENTES MONEDAS HOMEBANKING WEB' (query 1)
              select decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_fuerte,nvl(a.monto,0),a.cotizacion),0) mto_compra_usd,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_fuerte,nvl(a.monto,0),a.cotizacion),0) mto_venta_usd,
                     decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_local,nvl(a.monto,0),a.cotizacion),0) mto_compra_gs,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_local,nvl(a.monto,0),a.cotizacion),0) mto_venta_gs,
                     t.tipo, a.nro_documento
                from GE_MOVIMIENTOS_ant a, GE_TRANSACCIONES t
               where a.cod_usuario in ('HOMEBANK', 'HBANK')
                 and a.cod_mod_padre in (7, 9)
                 and a.cod_tra_padre = 388
                 and a.reversado = 'N'
                 and nvl(trim(a.cotizacion), ' ') <> ' '
                 and a.cod_usu_reversion is null
                 and a.nro_secuencia in (1, 2)
                 and ((fug_es_empleado(fug_obt_cli_principal(a.nro_cuenta)) = 'S' and
                        (select count(1) from gv_movimientos b where b.fecha = a.fecha and b.hora = a.hora and b.cod_usuario = a.cod_usuario and b.nro_documento = a.nro_documento and b.cod_moneda = a.cod_moneda) = 1
                     ) or (
                       ((select count(1) from lc_movimientos_his lm where a.fecha = lm.fecha and a.hora = lm.hora and a.cod_usuario = lm.cod_usuario and a.nro_documento = lm.nro_documento and a.cod_moneda != lm.cod_moneda) > 0) or
                       ((select count(1) from cc_movimientos_his cm where a.fecha = cm.fecha and a.hora = cm.hora and a.cod_usuario = cm.cod_usuario and a.nro_documento = cm.nro_documento and a.cod_moneda != cm.cod_moneda) > 0) or
                       ((select count(1) from ah_movimientos_his am where a.fecha = am.fecha and a.hora = am.hora and a.cod_usuario = am.cod_usuario and a.nro_documento = am.nro_documento and a.cod_moneda != am.cod_moneda) > 0) or
                       ((select count(1) from ge_movimientos gm where a.fecha = gm.fecha and a.hora = gm.hora and a.cod_usuario = gm.cod_usuario and a.nro_documento = gm.nro_documento and a.cod_moneda != gm.cod_moneda) > 0)
                     ))
                 and a.cod_modulo = t.cod_modulo (+)
                 and a.cod_modalidad = t.cod_modalidad (+)
                 and a.cod_transaccion = t.cod_transaccion (+)
                 and t.tipo in('C', 'D')
                 and v_bcp_monto > decode(a.cod_moneda, v_mon_fuerte, a.monto, pag_gen.fu_con_mon_a_moneda(a.cod_moneda, v_mon_fuerte, a.monto, a.cotizacion))
              union
              --Referencia del 3er select: consulta dinamica 'TRA_MON_HB - TRANSFERENCIAS REALIZADAS ENTRE DIFERENTES MONEDAS HOMEBANKING WEB' (query 2)
              select decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_fuerte,nvl(a.monto,0),a.cotizacion),0) mto_compra_usd,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_fuerte,nvl(a.monto,0),a.cotizacion),0) mto_venta_usd,
                     decode(t.tipo,'D',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_local,nvl(a.monto,0),a.cotizacion),0) mto_compra_gs,
                     decode(t.tipo,'C',pal_cam.fu_con_mon_a_moneda(a.cod_moneda,v_mon_local,nvl(a.monto,0),a.cotizacion),0) mto_venta_gs,
                     t.tipo, a.nro_documento
                from GE_MOVIMIENTOS_ant a, LC_OPE_PENDIENTES l, GE_TRANSACCIONES t
               where a.cod_usuario in ('HOMEBANK', 'HBANK')
                 and a.cod_mod_padre in (7, 9)
                 and a.cod_tra_padre = 388
                 and a.reversado = 'N'
                 and nvl(trim(a.cotizacion), ' ') <> ' '
                 and a.cod_usu_reversion is null
                 and a.fecha = l.fec_operacion
                 and a.nro_documento = l.nro_operacion
                 and a.cod_modulo = t.cod_modulo (+)
                 and a.cod_modalidad = t.cod_modalidad (+)
                 and a.cod_transaccion = t.cod_transaccion (+)
                 and t.tipo in('C', 'D')
                 and v_bcp_monto > decode(a.cod_moneda, v_mon_fuerte, a.monto, pag_gen.fu_con_mon_a_moneda(a.cod_moneda, v_mon_fuerte, a.monto, a.cotizacion)) ) m
    group by m.tipo;

   CURSOR c_datos IS --Cursor de los datos a enviar
      Select l.id_datatec, l.tip_operacion, l.mercado, l.origen, l.operacion, l.usu_datatec, l.fec_transaccion,
             l.hor_transaccion, l.fec_ini_contrato, l.fec_fin_contrato, l.tip_registro, l.tip_tasa, l.tas_interes,
             l.val_amortizacion, l.precio, l.monto, l.cod_moneda, l.cod_mon_contraparte, l.tip_indentificacion,
             l.id_contraparte, l.observacion, l.cumplimiento, l.sis_origen, l.ciudad
        from lc_inf_datatec l where l.fec_transaccion = v_fecha and l.estado = 'I' and l.observacion = 'Consolidado Minorista';

   -- Procedimiento interno para generar nuevo identificador de registro de consolidados minoristas
   PROCEDURE lp_gen_id_consolidado(p_dato in out NUMBER) IS --2019.08.count(9999)
     v_base      NUMBER(10) := to_number(to_char(v_fecha,'YYYYMM'));
     v_anterior  NUMBER(10);
   BEGIN
     --se busca el id anterior
     select nvl(max(id_datatec),0)
       into v_anterior
       from lc_inf_datatec d
      where observacion = 'Consolidado Minorista';

     if(substr(to_char(v_anterior),1,6) = v_base ) then
       --si es del mismo anho/mes solo le sumamos +1
       p_dato := v_anterior + 1;
     else
       --si no, creamos nuevo id anho/mes..
       p_dato := to_number(to_char(v_base)||'0001');
     end if;
   END;

   -- Procedimiento interno para registrar los errores
   PROCEDURE lp_ins_log_error(p_men_error ge_pro_aut_logs.men_error%type)
   IS
     v_proceso NUMBER(3) := 155;
     pragma autonomous_transaction;
   BEGIN
     insert into ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
        values (v_proceso, 'PRL_GEN_INF_CON_DATATEC', sysdate, sysdate, p_men_error);
     commit; -- este commit solo afecta a la transaccion autonoma
   END;

BEGIN
  IF v_enc_apag = 'S' THEN
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(7);
    if v_est_modulo = 2 then -- Solo ejecutar con modulo Abierto.
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
      
      --Verificamos si ya se informo el consolidado el dia de hoy
      select count(*) into v_yaInformado from lc_inf_datatec where observacion = 'Consolidado Minorista' and estado = 'E' and fec_transaccion = v_fecha;
      
      IF v_yaInformado = 0 THEN
        BEGIN --Si se cargo pero no se genero, se elimina el registro para volver a cargar
          Delete from lc_inf_datatec lc where lc.observacion = 'Consolidado Minorista' and lc.estado = 'I' and lc.fec_transaccion = v_fecha;
        EXCEPTION
          WHEN OTHERS THEN
            lp_ins_log_error(SUBSTR('Delete de consolidado no informado del dia: '||sqlerrm,1,500));
        END;

        BEGIN --Buscamos los datos e insertamos en la tabla
           FOR dato IN c_minoristas LOOP
             lp_gen_id_consolidado(v_id_consol);
             insert into lc_inf_datatec (id_datatec, tip_operacion, mercado, origen, operacion, usu_datatec, fec_transaccion,
                         hor_transaccion, fec_ini_contrato, fec_fin_contrato, tip_registro, tip_tasa, tas_interes,
                         val_amortizacion, precio, monto, cod_moneda, cod_mon_contraparte, tip_indentificacion,
                         id_contraparte, observacion, cumplimiento, sis_origen, ciudad, estado)
               values (v_id_consol, dato.tip_operacion, dato.mercado, dato.origen, dato.operacion, v_usu_datatec, dato.fec_transaccion,
                       dato.hor_transaccion, dato.fec_ini_contrato, dato.fec_fin_contrato, dato.tip_registro, dato.tip_tasa, dato.tas_interes,
                       dato.val_amortizacion, dato.precio, dato.monto, dato.cod_moneda, dato.cod_mon_contraparte, dato.tip_indentificacion,
                       dato.id_contraparte, dato.observacion, dato.cumplimiento, dato.sis_origen, dato.ciudad, 'I');
           END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
               lp_ins_log_error(SUBSTR('Insert a tabla lc_inf_datatec: '||sqlerrm,1,500));
        END;

        --Verificamos si tenemos registros para enviar
        select count(*) into v_hayDatos from lc_inf_datatec where observacion = 'Consolidado Minorista' and estado = 'I' and fec_transaccion = v_fecha;

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
            v_precio      := ltrim(to_char(dato.precio,'9999.9999'));
            v_monto       := ltrim(to_char(dato.monto,'999999999.99'));
            v_fec_ope     := to_char(dato.fec_transaccion,'YYYY-MM-DD');
            v_texto := v_tab||'<transaccion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<id>'                        ||dato.id_datatec          ||'</id>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<tipo_operacion>'            ||dato.tip_operacion       ||'</tipo_operacion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<mercado>'                   ||dato.mercado             ||'</mercado>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<origen>'                    ||dato.origen              ||'</origen>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<operacion>'                 ||dato.operacion           ||'</operacion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<id_usuario>'                ||dato.usu_datatec         ||'</id_usuario>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<fecha_transaccion>'         ||v_fec_ope                ||'</fecha_transaccion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<hora_transaccion>'          ||dato.hor_transaccion     ||'</hora_transaccion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<fecha_inicio_contrato>'     ||dato.fec_ini_contrato    ||'</fecha_inicio_contrato>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<fecha_fin_contrato>'        ||dato.fec_fin_contrato    ||'</fecha_fin_contrato>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<tipo_registro>'             ||dato.tip_registro        ||'</tipo_registro>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<tipo_tasa_1>'               ||dato.tip_tasa            ||'</tipo_tasa_1>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<tasa_interes>'              ||dato.tas_interes         ||'</tasa_interes>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<valor_amortizacion>'        ||dato.val_amortizacion    ||'</valor_amortizacion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<precio>'                    ||v_precio                 ||'</precio>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<monto_transado>'            ||v_monto                  ||'</monto_transado>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<moneda_monto>'              ||dato.cod_moneda          ||'</moneda_monto>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<moneda_contraparte>'        ||dato.cod_mon_contraparte ||'</moneda_contraparte>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<tipo_identificacion>'       ||dato.tip_indentificacion ||'</tipo_identificacion>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<identificacion_contraparte>'||dato.id_contraparte      ||'</identificacion_contraparte>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<comentario>'                ||dato.observacion         ||'</comentario>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<cumplimiento>'              ||dato.cumplimiento        ||'</cumplimiento>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<sistema_origen>'            ||dato.sis_origen          ||'</sistema_origen>'||v_salto;
            v_texto := v_texto||v_tab||v_tab||'<lugar_transaccion>'         ||dato.ciudad              ||'</lugar_transaccion>'||v_salto;
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
  END IF;
EXCEPTION
  when others then
    lp_ins_log_error(SUBSTR(''||sqlerrm,1,500));
END;
/

