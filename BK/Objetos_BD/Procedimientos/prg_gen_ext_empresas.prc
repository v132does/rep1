create or replace procedure it.prg_gen_ext_empresas IS
  v_file         UTL_FILE.FILE_TYPE;
  v_line         VARCHAR2(32767);
  v_linetit      VARCHAR2(2000);
  v_buffer       VARCHAR2(32767);
  v_lines        PLS_INTEGER := 0;
  v_eol          CONSTANT VARCHAR2(1) := CHR(10);
  v_eollen       CONSTANT PLS_INTEGER := LENGTH(v_eol);
  v_maxline      CONSTANT PLS_INTEGER := 32767;
  v_nro_cuenta   ge_cuentas.nro_cuenta%type;
  v_cod_persona  ba_personas.cod_persona%type;
  v_name         VARCHAR2(128);-- nombre del archivo
  v_dato         VARCHAR2(1);
  sum_cre        ge_ext_cli_movimientos_tmp.mto_credito%type;
  sum_deb        ge_ext_cli_movimientos_tmp.mto_debito%type;
  sal_ant        ge_ext_cli_cuentas_tmp.sal_anterior%type;
  v_det_error    varchar2(1000);
 

  -- Variables de fechas
  v_fec_sist DATE := pag_cal.FU_OBT_FEC_ACTUAL(1);
  v_fecha    VARCHAR2(8) := to_char(v_fec_sist, 'DDMMYYYY');

  -- Variables para FTP
  v_respuesta VARCHAR2(4000);
  v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
  v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

  -- Variables coneccion
  g_repository         VARCHAR2(100) := 'MAIL';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_ip                 VARCHAR2(100) := '192.168.254.136';
  g_ip                 VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
  g_port               VARCHAR2(100) := '21';
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_user               VARCHAR2(100) := 'ftpramail';
  g_user               VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_pass               VARCHAR2(100) := 'kacha.ma1';
  g_pass               VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
  --CRO-MB-05/2015: CROMIGDS-3 => Migración de Directorios de un Servidor a Otro
  --g_compartido         VARCHAR2(100) := '\\192.168.254.136\';
  g_compartido         VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
  g_conciliaciones     VARCHAR2(100) := 'ramail\Vierci\';

  CURSOR cuentas IS
    select val_minimo, val_maximo
      from ba_cod_referencias
     where dominio = 'EXT_NRO_CUENTA';
  
  CURSOR cab_cta IS
    SELECT cod_oficina,
           nro_cuenta,
           cod_persona,
           fec_extracto,
           cod_moneda,
           fre_extracto,
           cod_extracto,
           (decode(sign(a.sal_anterior), -1, '-', '') || nvl(abs(a.sal_anterior), 0)) sal_anterior,
           (decode(sign(a.sal_actual), -1, '-', '') || nvl(abs(a.sal_actual), 0)) sal_actual,
           sal_a_confirmar,
           decode(a.cod_modalidad,41,'CC',31,'CA') cod_modalidad,
           sigla
      FROM ge_ext_cli_cuentas_tmp a, ge_modalidades b
     WHERE a.cod_modulo = b.cod_modulo
       AND a.cod_modalidad = b.cod_modalidad
       AND nro_cuenta in v_nro_cuenta
     ORDER BY cod_persona, nro_cuenta, fec_extracto;

  CURSOR det_cta IS
     SELECT fec_movimiento,
            fec_valor,
            hor_movimiento,
            nvl(nro_documento, 0) nro_documento,
            nvl(a.mto_debito, 0) mto_debito,
            nvl(a.mto_credito, 0) mto_credito,
            substr(descripcion, 1, 41) descripcion
       FROM ge_ext_cli_movimientos_tmp a, ge_transacciones b
      WHERE a.cod_tra_padre = b.cod_transaccion
        AND a.cod_modulo = b.cod_modulo
        AND a.cod_modalidad = b.cod_modalidad
        AND nro_cuenta in v_nro_cuenta
        AND fec_movimiento = v_fec_sist
      ORDER BY fec_movimiento, fec_valor, hor_movimiento;

BEGIN
  FOR cta IN cuentas LOOP
     v_nro_cuenta:=null;
     v_cod_persona:=null;
     v_nro_cuenta:=cta.val_minimo;
     v_cod_persona:=cta.val_maximo;
     -- Genera Extracto a Requerimiento.
     begin
       prg_gen_extracto_tmp(v_cod_persona,v_nro_cuenta,null);
     exception
       when others then
         v_det_error := substr(sqlerrm,1,4000);
     end;
     -- Busca si Generó Extracto a Requerimiento
     v_dato := 'N';
     begin
       select distinct 'S'
         into v_dato from ge_ext_cli_cuentas_tmp et
        where et.nro_cuenta = v_nro_cuenta;
     exception
       when no_data_found then v_dato := 'N';
     end;
     
     v_buffer := null;
     v_line := null;
     
     if v_dato = 'S' then
        
        FOR rec IN cab_cta LOOP
          v_buffer := null;
          v_line := null;
          v_name:=  v_fecha ||'_'||v_nro_cuenta;
              
          -- Abrir archivo
          v_file := UTL_FILE.FOPEN(g_repository,
                                   v_name || '.txt',
                                   'W',
                                   32767);
          sal_ant:=0;
          sum_deb:=0;
          sum_cre:=0;
          begin
             SELECT sum(nvl(a.mto_debito, 0)) mto_debito,
                    sum(nvl(a.mto_credito, 0)) mto_credito
               INTO sum_deb, sum_cre
               FROM ge_ext_cli_movimientos_tmp a, ge_transacciones b
              WHERE a.cod_tra_padre = b.cod_transaccion
                AND a.cod_modulo = b.cod_modulo
                AND a.cod_modalidad = b.cod_modalidad
                AND nro_cuenta in v_nro_cuenta
                AND fec_movimiento = v_fec_sist;
          exception
            when no_data_found then
               sum_deb:=0;
               sum_cre:=0;
          end;
          sal_ant:= nvl(rec.sal_actual, 0)+ nvl(sum_deb,0)-nvl(sum_cre,0);
        
          -- Colocar los campos de la cabecera
          v_linetit := lpad(nvl(rec.nro_cuenta, 0), 15) ||
                       rec.cod_modalidad ||
                       lpad(rec.cod_moneda,3) ||
                       REPLACE(lpad(sal_ant, 18, 0),',', '.') ||
                       REPLACE(lpad(rec.sal_actual, 18, 0),',', '.') || chr(13);
            
          utl_file.put_line(v_file, v_linetit);

          FOR REC1 IN det_cta LOOP
            --Detalle
            v_line := to_char(rec1.fec_movimiento, 'dd/mm/yyyy') ||
                      to_char(rec1.fec_valor, 'dd/mm/yyyy') ||
                      lpad(rec1.descripcion, 50) ||
                      lpad(nvl(rec1.nro_documento,0), 15, 0) ||
                      REPLACE(lpad(rec1.mto_debito, 18, 0), ',', '.') ||
                      REPLACE(lpad(rec1.mto_credito, 18, 0), ',', '.') || chr(13);

            IF LENGTH(v_buffer) + v_eollen + LENGTH(v_line) <= v_maxline THEN
              v_buffer := v_buffer || v_eol || v_line;
            ELSE
              IF v_buffer IS NOT NULL THEN
                --Escribes la linea en el fichero
                UTL_FILE.PUT_LINE(v_file, v_buffer);
              END IF;
              v_buffer := v_line;
            END IF;
              
            v_lines := v_lines + 1;
         
            EXIT WHEN det_cta%NOTFOUND;
          END LOOP;
            
          --Escribes la linea en el fichero
          UTL_FILE.PUT_LINE(v_file, v_buffer);
          --Cerrar el handler al fichero
          UTL_FILE.FCLOSE(v_file);
          COMMIT;

          v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');

          -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
          v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                                  g_port,
                                                  g_user,
                                                  g_pass,
                                                  g_repository,
                                                  v_name || '.txt',
                                                  g_conciliaciones || v_name|| '.txt');

          v_hfin_ftp := to_char(sysdate, 'hh24:mi:ss');
          COMMIT;
        END LOOP;
      end if;
  END LOOP;
EXCEPTION
  WHEN UTL_FILE.INVALID_OPERATION THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20061, 'Operacion invalida ' || sqlerrm);
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20062, 'Manejador invalido ' || sqlerrm);
  WHEN UTL_FILE.WRITE_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20063, 'Error de escritura ' || sqlerrm);
  WHEN UTL_FILE.INVALID_MODE THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20064, 'Modo invalido ' || sqlerrm);
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    UTL_FILE.FCLOSE(v_file);
    RAISE_APPLICATION_ERROR(-20065, 'Internal Error ' || sqlerrm);
END prg_gen_ext_empresas;
/

