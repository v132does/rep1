CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_CON_BANCARD (
p_fecha date default null
)is
  v_fec_actual      date:=  pag_cal.fu_obt_fec_actual(1);
  v_fec_anterior    date;
  v_texto_detalle   varchar2(32000);
  v_adjunto         varchar2(32000);
  v_nro_lote        number(18);
  v_nro_registro    number(18);
  v_total_procesado number ;
  v_line            VARCHAR2(32767);
  v_file            UTL_FILE.FILE_TYPE;
  v_name            VARCHAR2(128);-- nombre del archivo
  v_cantidad        number(18):=0;
  v_hora            varchar2(12);
  v_error           varchar2(3000);
  v_hor_cierre      VARCHAR2(19);
  v_hor_cie_anterior VARCHAR2(19);
  -- FTP
  v_hini_ftp        ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp        ge_ra_log_ftp.hor_fin%type;
  v_respuesta       VARCHAR2(4000);
  /* -- Variables conexion*/
  v_repository      VARCHAR2(100) := 'MAIL';
  g_ip              VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port            VARCHAR2(100) := '21';
  g_user            VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  g_pass            VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  ---
  v_directorio      VARCHAR2(100) := fug_obt_pardinamico('DIR_GEN_CON_BANCARD');
  ---
  v_tip_movimiento varchar2(1);
  v_fec_movimiento date;
  v_hor_movimiento  varchar2(8);
  v_imp_movimiento varchar2(18);
  v_mon_movimiento varchar2(3);
  v_extornado      varchar2(1);
  v_cre_deb        varchar2(1);
  v_imp_formateado varchar2(100);
  v_can_decimales  number(18);
  v_longitud       number(10);
  v_diferencia     number(10);
  v_importe        number(18,2);
  v_registro       varchar2(3000);
  v_fec_ult_extracto date;
  v_nro_boleta     varchar2(100);
  v_concepto       varchar2(100);
  --
  v_hfin_mail varchar2(100);
  v_hini_mail varchar2(100);
  v_para     varchar2(300);
  v_det_error    varchar2(2000);
  v_lugar varchar2(3000);
  v_err_code NUMBER(5);
  v_err_msj  VARCHAR2(4000);
  v_can_registros number(10);

CURSOR g_cuenta is
    select b.nro_cuenta
      from GE_CUENTAS b
     where b.cod_sub_modalidad=25;


CURSOR g_datos is
    select a.* from GE_ARC_CON_BANCARD a
       where  a.nro_lote= v_nro_lote
        and  nvl(a.enviado,'N')='N'
          order by a.nro_registro;

CURSOR c_rec(v_cta_debito ge_cuentas.nro_cuenta%TYPE) is
SELECT     distinct a.cod_oficina,
            a.nro_cuenta,
            a.cod_persona,
            a.fecha,
            a.hora,
            a.fec_valor,
            a.cod_moneda,
            a.monto monto,
            0 debe,
            a.estado,
            upper(a.concepto) concepto,
            a.cod_tra_padre,
            a.nro_documento,
            'S' facturador,
            NVL(nvl(a.nro_documento3,a.NRO_DOCUMENTO),a.NRO_DOCUMENTO4) nro_documento3,
            a.tip_mov_rubro,
            a.usu_insercion,
            a.usu_modificacion,
            a.cod_transaccion,
            a.cod_usuario,
            a.nro_secuencia,
            a.fec_insercion,
            a.cod_modulo,
            a.cod_modalidad,
            a.reversado,
            a.cod_mad_padre,
            --a.DES_TRANSACCION as descripcion
             fug_obt_des_transaccion(a.cod_mod_padre, a.cod_mad_padre, a.cod_tra_padre) as descripcion,
             a.COD_TIP_MOVIMIENTO as COD_TIP_MOVIMIENTO
          FROM ge_transacciones b, gv_movimientos a
          WHERE nro_cuenta = v_cta_debito
            AND trunc(a.fecha) = trunc(v_fec_anterior)
            AND estado = 'N'
            AND (a.reversado = 'N'
             OR (a.reversado = 'S' )
             OR (a.reversado = 'S' and a.COD_TRA_PADRE in (303, 302) and a.COD_MAD_PADRE= 455)-- BBVASOP-888/AP 3056
            )
            AND a.monto <> 0
            AND a.cod_tip_movimiento IN ('D', 'C')
            AND a.cod_modulo = b.cod_modulo
            AND a.cod_modalidad = b.cod_modalidad
            AND a.cod_transaccion = b.cod_transaccion
            AND b.ve_cliente = 'S'
            AND NOT EXISTS (SELECT 0
                   FROM ah_retenciones x
                  WHERE x.nro_cuenta = a.nro_cuenta
                    AND x.nro_documento = a.nro_documento
                    AND x.cod_retencion = a.cod_retencion
                    AND x.fec_final = a.fec_fin_retencion
                    AND x.liberado = 'N')
          ORDER BY a.nro_cuenta, a.HORA asc,a.NRO_DOCUMENTO asc;
begin
  BEGIN PRE_INI_APLICACION;PAE_CNF.G_COD_MODULO:=1; END;
  v_lugar:='Ingresa';
  pre_cam_for_numerico('.,');
  v_lugar:='Seteo 1';
  v_hfin_mail := to_char(sysdate, 'hh24:mi:ss');
  v_hini_mail := to_char(sysdate, 'hh24:mi:ss');
  v_lugar:='Seteo 2';
  v_para:= fug_obt_pardinamico('CAM_MAR_DIR_MAIL');--'info@bbva.com';
  v_lugar:='Ingresa Cuerpo:'|| v_fec_actual;
   --Consulta para hacer el proceso recurrente, y que si ya se ejecutó, ya no vuelva a ejecutarse afectando registros

  select count(*) as cant 
  into v_can_registros
  from GE_ARC_CON_BANCARD a  
  where  trunc(a.fec_insercion) = trunc(sysdate);

  --si ya existen registros en la tabla ge_arc_con_bancard
  IF(v_can_registros = 0) then
  --Para que solo genere los dias habiles
   IF trunc(sysdate) = trunc(v_fec_actual) then
     v_lugar:='Entro';
    v_hor_cierre:= null;
    v_hor_cie_anterior:= null;
    v_fec_actual:= nvl(p_fecha,v_fec_actual);
    --Hora de cierre de la fecha
    --v_hor_cierre:= to_char(v_fec_actual,'dd/mm/yyyy')||' '||nvl(substr(trim(fug_obt_pardinamico('HOR_CIE_CON_BANCARD')),1,5),'14:00')||':00';
    --Hora de cierre del día anterior
     v_lugar:='Obtener Fecha Anterior';
      begin
        select w.fec_anterior
         into v_fec_anterior
          from ge_calendarios w
           where w.cod_modulo=1;
      exception
         when no_data_found then
             v_fec_anterior:= trunc(sysdate) -1;
         when others then
             v_fec_anterior:= trunc(sysdate) -1;
      end;
    --
    --v_hor_cie_anterior:= to_char(v_fec_anterior,'dd/mm/yyyy')||' '||nvl(substr(trim(fug_obt_pardinamico('HOR_CIE_CON_BANCARD')),1,5),'14:00')||':00';
    --
     v_lugar:='Obtener Directorio';
     if v_directorio is null then
               -- Insertamos el error del envio al directorio compartido
               INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
               VALUES (SYSDATE,v_name,'Con.Arc.BANCARD, no se encuentra parametrizado el directorio compartido', v_hini_ftp,v_hfin_ftp);
               INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
               VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, 'Con.Arc.BANCARD, no se encuentra parametrizado el directorio compartido');
     end if;
     v_lugar:='Obtener Repositorio';
     if v_repository is null then
              --Insertamos en la tabla de logs
              INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
              VALUES (SYSDATE,v_name,'Con.Arc.BANCARD, no se encuentra parametrizado el repositorio compartido', v_hini_ftp,v_hfin_ftp);
               INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
               VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, 'Con.Arc.BANCARD, no se encuentra parametrizado el directorio compartido');
     end if;
     --Nombre de Archivo
     v_lugar:='Cargar Nombre';
     v_name := 'extracto_cuentas' ||'_' ||to_char(v_fec_anterior, 'yyyymmdd')|| '.txt';
     v_name:=lower(v_name);
     v_nro_lote:=0;
     v_lugar:='Obtener Secuencia 1';
     v_nro_lote:= S_NRO_LOTE_CON_BANCARD.Nextval ;
     -- Abrir archivo
    if v_repository is not null and v_directorio is not null then
                  v_lugar:='Abrir archivo';
                  v_file := UTL_FILE.FOPEN(v_repository,
                                          lower(v_name),
                                          'W',
                                          32767);
    end if;

    for a in g_cuenta loop
           --Seteos iniciales
          v_texto_detalle := null;
          v_adjunto       := null;
          v_total_procesado := 0;
          v_line := null;
             --Cargamos la nueva tabla los detalles de operaciones
             v_total_procesado := 0;
             v_lugar:='Ingresar Carga';
             for z in c_rec(a.nro_cuenta) loop
                  v_lugar:='Cargar Registro:'||a.nro_cuenta;
                  --limpiamos variables
                 v_nro_registro:=0;
                 v_tip_movimiento:=null;
                 v_fec_movimiento:=null;
                 v_hor_movimiento:=null;
                 v_imp_movimiento:=null;
                 v_mon_movimiento:=null;
                 v_concepto:=null;
                 v_cre_deb:=null;
                 v_extornado:='N';
                 v_registro:= null;
                 v_imp_formateado:=null;
                 v_importe:=0;
                 v_longitud:=null;
                 v_diferencia:=null;
                 v_can_decimales:=0;
                 v_fec_ult_extracto:=null;
                 v_nro_boleta:=null;
                         v_lugar:='Obtener secuencia 2';
                         --asignamos valores
                         v_nro_registro:= S_NRO_REG_CON_BANCARD.Nextval ;
                        --Buscamos por la transaccion padre (para tipo de movimiento Bancard)
                         v_lugar:='Obtener referencia';
                         begin
                             select a.val_maximo
                              into v_tip_movimiento
                                from ba_cod_referencias a
                                  where a.val_minimo= to_char(z.cod_tra_padre)
                                  and upper(a.dominio)='TIP_OPE_BANCARD';
                         exception
                           when no_data_found then
                             v_tip_movimiento:='T';
                           when others then
                             v_tip_movimiento:='T';

                         end;

                         v_fec_movimiento:= z.fecha;
                         --La hora se informará tomando la hora de la fec_insercion
                         v_hor_movimiento:= substr(z.hora,1,2)||substr(z.hora,4,2)||substr(z.hora,7,2);
                         --v_hor_movimiento:=to_char(z.fec_insercion,'Hh24MiSs');
                         v_mon_movimiento := CASE z.cod_moneda
                                              WHEN 'USD' THEN 840
                                              WHEN 'GS'  THEN 600
                                              ELSE 000 END; -- 600 (guaranies) u 840 (dolares)
                         v_extornado := 'N';--S/N
                         if z.monto < 0 then
                           v_extornado := 'S';
                         end if;
                         v_cre_deb := z.cod_tip_movimiento; --(C/D)
                         --Sino tiene Buscamos de la Transaccion
                         if v_cre_deb is null then
                             begin
                               select x.tipo
                                into v_cre_deb
                                from ge_transacciones x
                                  where x.cod_transaccion= z.cod_transaccion
                                     and x.cod_modulo=z.cod_modulo
                                     and x.cod_modalidad=z.cod_modalidad
                                     and rownum=1;
                            exception
                              when no_data_found then
                                v_cre_deb:='E';
                              when others then
                                v_cre_deb:='E';
                             end;
                         end if;

                         --Si es negativo, se tiene que informar positivo
                             v_lugar:='Cargar Monto';
                            if z.monto < 0 then
                              v_importe:=(z.monto*-1);
                              if v_cre_deb ='C' then
                                v_cre_deb:='D';
                              elsif v_cre_deb ='D' then
                                 v_cre_deb:='C';
                              end if;
                            else
                              v_importe:= z.monto;
                            end if;

                            if v_mon_movimiento = 600 then
                              v_lugar:='Fotmat Importe'||v_importe;
                              --GS
                              v_imp_formateado:=lpad(v_importe||'00',15,0);
                            elsif v_mon_movimiento = 840 then
                              --USD Buscamos por '.' dependiendo de la Base de Datos
                               v_lugar:='Fotmat Importe 11:'||v_importe;
                              v_can_decimales:= instr(to_char(v_importe),'.');
                              if v_can_decimales > 0 then
                                 v_lugar:='Fotmat Importe 111:'||v_importe;
                                 v_longitud:=  length(to_char(v_importe));
                                 v_diferencia:=v_longitud - v_can_decimales;
                                 if v_diferencia= 1 then
                                   v_imp_formateado:=lpad(replace(to_char(v_importe),'.','')||'0',15,0);
                                 elsif v_diferencia= 2 then
                                   v_imp_formateado:=lpad(replace(to_char(v_importe),'.',''),15,0);
                                 end if;
                              else
                                --Buscamos por ',' dependiendo de la Base de Datos
                                 v_lugar:='Fotmat Importe 1V:'||v_importe;
                                 v_can_decimales:= instr(to_char(v_importe),',');
                                 if v_can_decimales > 0 then
                                    v_longitud:=  length(to_char(v_importe));
                                    v_diferencia:=v_longitud - v_can_decimales;
                                     if v_diferencia= 1 then
                                       v_imp_formateado:=lpad(replace(to_char(v_importe),',','')||'0',15,0);
                                     elsif v_diferencia= 2 then
                                       v_imp_formateado:=lpad(replace(to_char(v_importe),',',''),15,0);
                                     end if;
                                 else
                                   v_imp_formateado:=lpad(v_importe||'00',15,0);
                                 end if;
                              end if;
                            else
                              v_imp_formateado:=lpad(v_importe,15,0);
                            end if;
                            --Si es administrativo, y estas transacciones padre y no tienen Cta de Bancard cargada
                            --Se informa el Nro de Documento Nuestro
                            if z.cod_tra_padre in(145,148,517) AND z.usu_insercion  like 'ATM%' then
                              v_tip_movimiento:='T';
                            elsif  z.cod_tra_padre =309 AND z.usu_insercion  like 'ATM%' then
                                v_tip_movimiento:='A';

                            end if;

                            If v_tip_movimiento='A' and z.cod_tra_padre in(145,148,309,517)
                              AND z.usu_insercion not like 'ATM%' then
                              v_nro_boleta:= trim(nvl(z.nro_documento,z.nro_documento3));
                            else
                              v_nro_boleta:= trim(nvl(z.nro_documento3,z.nro_documento));
                            end if;


                            --Concepto
                              v_concepto:=trim(substr(z.descripcion,1,60));

                            if v_nro_boleta is null and z.cod_tra_padre='310' THEN
                              v_nro_boleta:=6483;
                            END IF;

                            v_lugar:='Armar registro';
                            --**** Armamos el Registro;
                            v_registro :=
                            rpad(z.nro_cuenta,15,' ') ||';'||
                            rpad(v_nro_boleta,15,' ') ||';'||
                            rpad(v_tip_movimiento,1,' ') ||';'||
                            rpad(to_char(z.fecha,'YyyyMmDd'),8,' ') ||';'||
                            rpad(v_hor_movimiento,6,' ') ||';'||
                            lpad(v_imp_formateado,15,0) ||';'||
                            rpad(v_mon_movimiento,3,' ') ||';'||
                            rpad(v_extornado,1,' ') ||';'||
                            rpad(v_cre_deb,1,' ') ||';'||
                            --rpad(v_concepto,30,' ')||';';
                            v_concepto||';';
                            --Insertamos los datos
                            v_lugar:='Insertar en Tabla: '||z.nro_documento;
                            insert into GE_ARC_CON_BANCARD(FECHA,
                                                          HORA,
                                                          COD_USUARIO,
                                                          NRO_SECUENCIA,
                                                          NRO_DOCUMENTO,
                                                          NRO_DOCUMENTO3,
                                                          NRO_LOTE,
                                                          NRO_REGISTRO,
                                                          REGISTRO,
                                                          Concepto
                                                          )
                                                      values(z.fecha,
                                                          z.hora,
                                                          z.cod_usuario,
                                                          z.nro_secuencia,
                                                          z.nro_documento,
                                                          z.nro_documento3,
                                                          v_nro_lote,
                                                          v_nro_registro,
                                                          v_registro,
                                                          v_concepto);

              end loop;
    end loop;
   --Verificamos si se insertaron registros en la tabla para enviar.
    v_cantidad:=0;
    begin
      select count(*)
        into v_cantidad
        from GE_ARC_CON_BANCARD a
         where a.nro_lote= v_nro_lote
         and   a.enviado='N';
    exception
      when no_data_found then
        v_cantidad:=0;
      when others then
         v_cantidad:=0;
    end;
     --Si se cargaron registros para el Lote, seguimos
     if nvl(v_cantidad,0)> 0 then
           if v_repository is not null and v_directorio is not null then
               Begin
                  -- Punto para la parte decimal y coma para separador de miles.
                  v_lugar:='Obtener Datos de Tabla';
                  for w in g_datos loop
                       v_lugar:='Cargar Datos';
                       v_adjunto :=rpad(w.registro,134,' ')|| chr(13) ;
                       UTL_FILE.PUT_LINE(v_file, v_adjunto);
                   end loop;
              EXCEPTION
                   when others then
                          v_hora:= to_char(sysdate,'hh24:mi:ss');
                          v_error:= substr(to_char(sqlerrm),1,3000);
                          INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                          VALUES (SYSDATE,v_name,v_error, v_hini_ftp,v_hfin_ftp);
                           INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
                           VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_error);
               END;

                --Enviamos el archivo por ftp
                --Cerrar el handler al fichero
                UTL_FILE.FCLOSE(v_file);
                COMMIT;
                v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
                -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
                 v_lugar:='Enviar archivo al Directorio Compartido';
                v_respuesta := pa_file_ftp.fu_put_binary(g_ip,
                                                        g_port,
                                                        g_user,
                                                        g_pass,
                                                        v_repository,
                                                        lower(v_name),
                                                        lower(v_directorio) || lower(v_name));
                 v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
                 IF v_respuesta <> 'OK' THEN
                    v_lugar:='Actualizar Error';
                      -- Insertamos el error del envio al directorio compartido
                      INSERT INTO ge_ra_log_ftp(fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
                      VALUES (SYSDATE,v_name,v_respuesta,v_hini_ftp,v_hfin_ftp);
                       INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
                      VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_respuesta);
                 else
                   --Envio sin problemas,actualizamos registros
                    v_lugar:='Actualizar Registro';
                   update GE_ARC_CON_BANCARD a
                     set a.enviado ='S'
                      where a.nro_lote= v_nro_lote;
                 end if;
                 COMMIT;

       end if;
     end if;

  end if;
  else
    PRG_ACT_LOG_PROCESOS('PRG_GEN_ARC_CON_BANCARD', 'PRG_GEN_ARC_CON_BANCARD', TRUNC(SYSDATE),'00:00:00','00:00:00',
  'El proceso ya fue ejecutado con cantidad ' || v_can_registros);
  END IF;
  --*********************************************************************************************************

EXCEPTION

   WHEN UTL_FILE.INVALID_OPERATION THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt','Operacion invalida '||v_lugar, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
    --RAISE_APPLICATION_ERROR(-20061, 'Operacion invalida ' || sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt','Manejador invalido  '||v_lugar, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
  --RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt','Error de escritura '||v_lugar, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
    --RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt','Modo invalido '||v_lugar, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
  --RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt','Internal Error '||v_lugar, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
     --RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
  WHEN OTHERS THEN
    v_err_msj  := substr(sqlerrm, 1, 4000);
    UTL_FILE.FCLOSE(v_file);
    v_lugar:='Otro error: ';
    v_det_error:= sqlerrm;
    INSERT INTO ge_ra_log_ftp (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
    VALUES (SYSDATE, nvl(v_name,'extracto_cuentas') || '_' || sysdate || '.txt',v_lugar||' '||v_det_error, v_hini_mail, v_hfin_mail);
    INSERT INTO ge_pro_aut_logs  (COD_PROCESO, nom_proceso, fec_hor_ini, fec_hor_fin, men_error)
    VALUES (190, 'PRG_GEN_ARC_CON_BANCARD', v_hini_mail, v_hfin_mail, v_err_msj);
END PRG_GEN_ARC_CON_BANCARD;
/

