CREATE OR REPLACE PROCEDURE IT.prg_gen_arc_nom_altas(p_nro_lote IN number,
                                                  p_cod_ente IN number) IS

    v_file   UTL_FILE.FILE_TYPE; 
    v_line   VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'EMP_BBVA_'||p_nro_lote||'_'||p_cod_ente||'.xls'; -- nombre del archivo
    
    v_desc_paisfisc ba_paises.descripcion%type;
    v_desc_pais2    ba_paises.descripcion%type;

    -- Variables para FTP
    v_respuesta VARCHAR2(4000);
    v_hini_ftp  ge_ra_log_ftp.hor_inicio%type;
    v_hfin_ftp  ge_ra_log_ftp.hor_fin%type;

    -- Variables coneccion
    g_repository     VARCHAR2(100) := 'MAIL';
    g_ip             VARCHAR2(100) := fug_obt_pardinamico('DIR_SVR_REP_ARCHIVOS');
    g_port           VARCHAR2(100) := '21';
    g_user           VARCHAR2(100) := fug_obt_pardinamico('USU_FTP_REP_ARCHIVOS');
    g_pass           VARCHAR2(100) := fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS');
    --g_compartido     VARCHAR2(100) := '\\'||fug_obt_pardinamico('PAS_FTP_REP_ARCHIVOS')||'\';
    g_conciliaciones VARCHAR2(100) := 'ramail\operaciones\';

    CURSOR arc_nom IS
      select a.tip_documento, a.nro_cedula, a.fec_vto_documento, a.doc_pais, a.pri_apellido, a.seg_apellido,
             a.ape_casada, a.pri_nombre||' '||a.seg_nombre nombres, a.fec_nacimiento, a.est_civil,
             a.pais pais_origen, a.sexo, a.direccion, a.telefono, a.celular, a.ciudad, a.fec_ingreso,
             a.profesion, a.sueldo, a.cod_empresa, a.mail, a.cod_pai_fatca pais2, a.dir_fiscal, a.cod_pai_fiscal,
             a.cod_sec_contable, a.direc_kit, decode(a.tip_contrato,'I','INDEFINIDO','T','TEMPORAL') tip_contrato, 
             a.sobregiro, a.nro_lote, a.estado
        from ge_pag_sue_emp_tmp a
       where a.nro_lote = nvl(p_nro_lote,0)
         and a.cod_empresa = p_cod_ente;

  BEGIN
    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(g_repository, v_name, 'W', 32767);

    --defino lineas en blanco para empezar desde la linea 8
    v_line := chr(10)||chr(10)||chr(10)||chr(10)||chr(10);
    utl_file.put_line(v_file,v_line);

    --Defino Cabecera
    v_line := 'EMPRESA'||chr(9)||'NRO LOTE'||chr(9)||'ESTADO'||chr(9)||'NRO. ORDEN'||chr(9)||
              'TIPO DE DOCUMENTO'||chr(9)||'N° DE DOCUMENTO'||chr(9)||'FECHA VENCIMIENTO DEL DOCUMENTO'||chr(9)||
              'PAIS DEL DOCUMENTO'||chr(9)||'PRIMER APELLIDO'||chr(9)||'SEGUNDO APELLIDO'||chr(9)||'APELLIDO CASADA'||chr(9)||
              'NOMBRES'||chr(9)||'FECHA DE NACIMIENTO'||chr(9)||'ESTADO CIVIL'||chr(9)||'PAIS DE NACIMIENTO'||chr(9)||
              'SEXO'||chr(9)||'DIRECCION/DOMICILIO PARTICULAR'||chr(9)||'LINEA BAJA'||chr(9)||'TELEFONO CELULAR'||chr(9)||
              'CIUDAD DEL DOMICILIO'||chr(9)||'FECHA DE INGRESO A LA EMPRESA'||chr(9)||'PROFESION'||chr(9)||
              'INGRESO BRUTO MENSUAL'||chr(9)||'COD EMPRESA'||chr(9)||'E-MAIL'||chr(9)||'SEGUNDA NACIONALIDAD'||chr(9)||
              'DIRECCION FISCAL EN EL EXTRAJERO'||chr(9)||'PAIS DE LA DIRECCION FISCAL'||chr(9)||'SECTOR CONTABLE'||chr(9)||
              'TIPO DE CONTRATO'||chr(9)||'DIRECCIONAMIENTO DE KITS'||chr(9)||'SOBREGIRO';
    UTL_FILE.PUT_LINE(v_file, v_line);

    --Definir un cursor for loop que recorre los datos obtenidos
    FOR x IN arc_nom LOOP
      --Busco descripcion del pais fiscal para generar archivo
      begin
        select p.descripcion
          into v_desc_paisfisc
          from ba_paises p
         where p.cod_pais = x.cod_pai_fiscal;
      exception
        when no_data_found then
          v_desc_paisfisc := null;
        when others then
          v_desc_paisfisc := null;
      end;
      --Busco descripcion del pais2 para generar archivo
      begin
        select p.descripcion
          into v_desc_pais2
          from ba_paises p
         where p.cod_pais = x.pais2;
      exception
        when no_data_found then
          v_desc_pais2 := null;
        when others then
          v_desc_pais2 := null;
      end;
      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := null||chr(9)||x.nro_lote||chr(9)||x.estado||chr(9)||null||chr(9)||x.tip_documento||chr(9)||
                ''''||x.nro_cedula||chr(9)||x.fec_vto_documento||chr(9)||x.doc_pais||chr(9)||x.pri_apellido||chr(9)||
                x.seg_apellido||chr(9)||x.ape_casada||chr(9)||x.nombres||chr(9)||to_char(x.fec_nacimiento,'dd/mm/yyyy')||chr(9)||
                x.est_civil||chr(9)||x.pais_origen||chr(9)||x.sexo||chr(9)||x.direccion||chr(9)||''''||x.telefono||chr(9)||
                ''''||x.celular||chr(9)||x.ciudad||chr(9)||to_char(x.fec_ingreso,'dd/mm/yyyy')||chr(9)||x.profesion||chr(9)||
                x.sueldo||chr(9)||x.cod_empresa||chr(9)||x.mail||chr(9)||v_desc_pais2||chr(9)||x.dir_fiscal||chr(9)||
                v_desc_paisfisc||chr(9)||x.cod_sec_contable||chr(9)||x.tip_contrato||chr(9)||x.direc_kit||chr(9)||x.sobregiro;
      UTL_FILE.PUT_LINE(v_file, v_line);
      EXIT WHEN arc_nom%NOTFOUND;
    END LOOP;

    --Cerrar el handler al fichero
    UTL_FILE.FCLOSE(v_file);

    v_hini_ftp := to_char(sysdate, 'hh24:mi:ss');
    -- Enviamos el archivo generado al directorio compartido mediante un servidor FTP
    v_respuesta := pa_file_ftp.fu_put_ascii(g_ip,
                                            g_port,
                                            g_user,
                                            g_pass,
                                            g_repository,
                                            v_name,
                                            g_conciliaciones || v_name);


    IF v_respuesta <> 'OK' THEN

      -- Insertamos el error del envio al directorio compartido
      INSERT INTO ge_ra_log_ftp
        (fec_envio, nom_archivo, det_error, hor_inicio, hor_fin)
      VALUES
        (SYSDATE,
         v_name,
         v_respuesta,
         v_hini_ftp,
         v_hfin_ftp);

    END IF;
    commit;
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
  END prg_gen_arc_nom_altas;
/

