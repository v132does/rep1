CREATE OR REPLACE PROCEDURE IT.PRL_GEN_INI_XML_CAMBIOS
IS
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
   v_reenvio      VARCHAR2(100)  := NVL(fug_obt_pardinamico('RE_ENV_POS_INI'),'N');
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
   v_existe       varchar2(1);
   v_cod_error    varchar2(3000);
   v_mensaje      varchar2(3000);
   v_date         DATE := NULL;
/*
p_tipo
O - Operaciones
I - Ssaldos Iniciales
*/
   
   CURSOR c_datos IS --Cursor de los datos a enviar
      Select l.id_operacion, l.nro_operacion,l.tip_operacion, l.mercado, l.origen, l.operacion, /*l.usu_datatec,*/ l.fec_transaccion,
             l.hor_transaccion, l.fec_ini_contrato, l.fec_fin_contrato, l.tip_registro, l.tip_tasa, l.tas_interes,
             l.val_amortizacion, l.precio, l.monto, l.cod_moneda, l.cod_mon_contraparte, l.tip_indentificacion,
             l.id_contraparte, l.observacion, l.cumplimiento, l.sis_origen, l.ciudad,l.sal_ini_dia, l.liquidado,l.usuario, l.tipo, l.sal_ini_for,
             l.nom_cliente,l.nro_cuenta
        from LC_INF_MIGRACION_XML l where l.fec_transaccion = v_fecha and l.estado = 'I' and l.observacion is null
        and l.tip_operacion is null;

  CURSOR c_monedas IS
      --monedas
      select a.*
         from ba_monedas a
           order by a.cod_moneda;

   -- Procedimiento interno para registrar los errores
   PROCEDURE lp_ins_log_error(p_men_error ge_pro_aut_logs.men_error%type)
   IS
     v_proceso NUMBER(3) := 156;
     pragma autonomous_transaction;
   BEGIN
     insert into ge_pro_aut_logs (cod_proceso, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
        values (v_proceso, 'PRL_GEN_INI_XML_CAMBIOS', sysdate, sysdate, p_men_error);
     commit; -- este commit solo afecta a la transaccion autonoma
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


BEGIN
    Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; end;
    v_est_modulo := pae_cnf.FU_OBT_EST_MODULO(7);
    v_tipo:='I';
    --Solo se ejecuta en fecha habil y para esa fecha de calendario
    if trunc(v_fecha) <> trunc(sysdate) then
                  --para que no siga
                  v_tipo:='W';
                  --No guardamos log, para no cargar devalde
    
    end if;
    --Validamos que no ne envie 2 veces en el dia
    if v_tipo=  'I' then
        v_env_ini:=0;
                --Verificamos si ya enviamos el inicial en la fecha, ya que si se envia 2 veces puede afectar procesos
                begin

                  select nvl(count(*),0)
                    into v_env_ini
                      from lc_inf_migracion_xml s
                        where trunc(s.fec_transaccion)= trunc(v_fecha)
                          and upper(S.TIPO)='INICIAL'
                          and estado='E';
                exception
                  when no_data_found then
                    v_env_ini:=0;
                end;
                IF nvl(v_env_ini,0)> 0 then
                     if v_reenvio = 'N' then
                        --para que no siga
                        v_tipo:='W';
                        --Grabamos Log
                        lp_ins_log_error(SUBSTR('Error- Ya se envió Saldo Ini., para reenvio par_din=(RE_ENV_POS_INI)=S - Fecha: '||TRUNC(v_fecha),1,500));
                     else
                         v_tipo:='I';
                         --actualizamos el par dnámico a N para re-enviar una sola vez, y no dejar activo
                         update GE_PAR_DINAMICOS A SET A.VAL_PARAMETRO='N' where a.parametro='RE_ENV_POS_INI';
                         commit;
                     end if;
                END IF;
    
    end if;

    
  
    
if v_tipo='I' then
  --Para Saldos Iniciales
    IF v_est_modulo = 2 THEN -- Solo ejecutar con modulo Abierto.
      BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;
         --Verificamos si ya se generó para la fecha

         v_existe:='N';
         v_cod_error:= null;
         v_mensaje:= null;
         
         BEGIN
           SELECT 'S'
             into v_existe
               from lc_tot_pos_cambios a
                 where trunc(a.fecha)= trunc(v_fecha)
                   and rownum=1;
         
         EXCEPTION
           WHEN NO_DATA_FOUND THEN
                v_existe:='N';
           when too_many_rows then
                v_existe:='S';
           WHEN OTHERS THEN
                v_existe:='N';
         END;
         
         if v_existe='S' then
            v_cod_error := 0;
         end if;
         
         IF nvl(v_existe,'N') = 'N' then
              pal_var.pr_cal_pos_cambio(v_fecha, NULL, NULL, NULL, NULL, NULL, NULL, v_cod_error, v_mensaje);
              IF v_cod_error = 10 THEN -- solo cuando existen registros bloqueados re-intentar cálculo
                 v_cod_error:= null;
                 v_mensaje:= null;
                 v_date := pai_int.smg_sleep('0.5');  -- se espera un momento para re-intentar el cálculo
                 --volver a probar una vez
                 pal_var.pr_cal_pos_cambio(v_fecha, NULL, NULL, NULL, NULL, NULL, NULL, v_cod_error, v_mensaje);
               end if;
          end if; 
         
         if v_cod_error <> 0 then
            lp_ins_log_error('Error gen pos:'||v_cod_error||'-'||v_mensaje ); 
         end if;
         
         if v_cod_error = 0  then
               FOR dato IN c_monedas LOOP --Buscamos los datos e insertamos en la tabla
                 v_informar:='S';
                 v_pos_ini_for:=0;
                 v_pos_ini_dia:= 0;
                 v_tip_moneda:= null;

                 if pag_gen.FU_OBT_MON_LOCAL = dato.cod_moneda then
                    v_tip_moneda:= 'GS';
                 else
                   v_tip_moneda:= 'ME';
                 end if;
                     v_pos_ini_for:= nvl(FF_OBT_INI_FUTURA (dato.cod_moneda,
                                    31,
                                    v_tip_moneda
                                    ),0) ;
                     --Buscamos el saldo inicial del dia SPOT para informar
                      begin
                         select nvl(z.pos_ini_me,0)
                           into v_pos_ini_dia
                           from lc_tot_pos_cambios z
                             where z.fecha=v_fecha
                               and z.cod_moneda= dato.cod_moneda;
                        exception
                          when no_data_found then
                            v_pos_ini_dia:=0;
                        end;
                  v_fec_transaccion:= v_fecha;

                    if  nvl(v_informar,'N') ='S' then
                              BEGIN
                                 v_nro_operacion:= null;
                                 v_id_operacion := it.S_COD_OPE_XML_CAM.nextval;
                                 v_nro_operacion:= v_id_operacion;
                                insert into LC_INF_MIGRACION_XML (id_operacion, nro_operacion,  fec_transaccion,
                                            sal_ini_dia,estado, Usuario,sal_ini_for,TIPO, liquidado,Cod_Moneda)
                                  values (v_id_operacion,v_nro_operacion,  v_fec_transaccion,
                                          v_pos_ini_dia, 'I',
                                          user, v_pos_ini_for, 'INICIAL','S', dato.cod_moneda);
                              EXCEPTION
                                  WHEN OTHERS THEN
                                      lp_ins_log_error(SUBSTR('Insert LC_INF_MIGRACION_XML INICIAL(nro_ope='||v_id_operacion||' Nro.ope'|| '): '||sqlerrm,1,500));
                              END;
                    end if;

                   END LOOP;
          end if;

      v_hayDatos:=0;
      --Verificamos si tenemos registros para envíar
      select count(*) into v_hayDatos from LC_INF_MIGRACION_XML where estado = 'I' and TIPO='INICIAL' and fec_transaccion = v_fecha and observacion is null;
      -- dbms_output.put_line('Hay Datos: '||v_hayDatos);
      IF v_hayDatos > 0 THEN
        BEGIN --Abrimos el archivo
           IF UTL_FILE.IS_OPEN (v_file) THEN
               UTL_FILE.FCLOSE (v_file);
           End IF;
           v_file := UTL_FILE.FOPEN(v_directorio, v_nom_archivo_ini,'W',32767) ;

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
          v_contador := v_contador + 1;
          v_cod_archivo := v_cod_archivo + 1;
          if v_contador > 1 then
             v_texto := null;
             v_tex_largo := null;
          end if;
          --v_precio      := ltrim(to_char(dato.precio,'9999.9999'));
          --v_monto       := ltrim(to_char(dato.monto,'999999999.99'));
          v_fec_ope     := to_char(dato.fec_transaccion,'YYYY-MM-DD');
          v_texto := v_tab||'<transaccion>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<id>'     ||dato.nro_operacion       ||'</id>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<fecha>'  ||v_fec_ope                ||'</fecha>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<moneda>' ||dato.cod_moneda          ||'</moneda>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<sal_ini_spot>'||dato.sal_ini_dia    ||'</sal_ini_spot>'||v_salto;
          v_texto := v_texto||v_tab||v_tab||'<sal_ini_forward>'||dato.sal_ini_for ||'</sal_ini_forward>'||v_salto;
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
                                                 v_nom_archivo_ini,
                                                 v_ubicacion||v_nom_archivo_ini);

        v_hfin_ftp  := to_char(sysdate, 'hh24:mi:ss');
       -- dbms_output.put_line('Resp:'||v_respuesta );
       IF v_respuesta <> 'OK' THEN --Error al enviar archivo por ftp. Insertamos el error del envio.
           INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
           VALUES (SYSDATE, v_nom_archivo_ini, v_respuesta, v_hini_ftp, v_hfin_ftp);
           COMMIT;

       ELSIF v_respuesta = 'OK' THEN --Si se envió correctamente, se cambia el estado del registro como Enviado*/
          FOR dato IN c_datos LOOP
            BEGIN
              update LC_INF_MIGRACION_XML
                 set estado = 'E'
               where id_operacion = dato.id_operacion
                 and estado = 'I';
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

