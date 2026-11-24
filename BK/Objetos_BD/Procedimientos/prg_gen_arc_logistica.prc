CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_LOGISTICA IS

    v_fec_ahorros   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_fec_ctacte    date := pag_cal.FU_OBT_FEC_ACTUAL(4);
    v_fec_anterior  date := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(1),7,1);

    v_file   UTL_FILE.FILE_TYPE;
    v_line   VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'ARC_LOGISTICA.xls'; -- nombre del archivo

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

    CURSOR arc_log IS
      select fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito) plastico,
             c.cod_oficina cod_ofi_origen,
             fug_obt_des_submodalidad(c.cod_modulo,c.cod_modalidad,c.cod_sub_modalidad) submodalidad,
             'CC' tipo_cta, c.denominacion embozado,
             fue_obt_per_ente(c.cod_ente) cod_per_ente,
             fue_obt_nom_ente(c.cod_ente) nom_ente,
             fue_obt_dir_principa(fue_obt_per_ente(c.cod_ente)) dir_ente,
             fue_obt_tel_principa(fue_obt_per_ente(c.cod_ente)) tel_ente,
             cta.cod_persona cod_persona, c.nro_cuenta nro_cuenta, t.adherente adherente, t.nro_emision nro_emision,
             (select fue_obt_tip_doc_abreviatura(p.cod_tip_documento) from ba_personas p
               where p.cod_persona = cta.cod_persona) tip_doc,
             fue_obt_nro_doc_persona(cta.cod_persona) nro_doc,
             (select pp.pri_nombre from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pri_nombre,
             (select pp.seg_nombre from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) seg_nombre,
             (select pp.pri_apellido from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pri_apellido,
             (select pp.seg_apellido from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) seg_apellido,
             fue_obt_dir_principa(cta.cod_persona) dir_cliente,
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'C' and rownum = 1) cel_cliente,
             (select b.direccion from ba_direcciones b where b.cod_persona = cta.cod_persona
                 and b.principal = 'N' and rownum = 1) dir_sec_cliente,
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'B' and rownum = 1) tel_cliente,
             fug_obt_dir_mail_per(cta.cod_persona) mail,
             (select pp.fec_nacimiento from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) fec_nacimiento,
             (select pp.cod_sexo from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) sexo,
             (select fue_obt_des_pais(pp.cod_pai_nacionalidad) from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pais,
             (select pp.est_civil from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) est_civil,
             (select 'S' from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona and pp.est_civil = 'B') sep_bienes,
             null conyugue, null cony_tip_doc, null cony_nro_doc,
             fue_obt_des_oficina(c.cod_oficina) des_oficina,
             fug_obt_cod_usu_oficial(cta.cod_persona) oficial, c.fec_apertura fec_apertura,
             (select emp.direc_kit from ge_pag_sue_emp emp where emp.nro_cuenta = c.nro_cuenta
                 and trunc(emp.fec_insercion) = trunc(c.fec_insercion)and rownum = 1) destino,
             (select sec.descripcion from ge_sec_contables sec where sec.cod_sec_contable = fug_obt_sec_contable(cta.cod_persona)) sec_econ,
             null nro_guia, c.usu_insercion usu_insercion, case when t.cod_ent_procesadora is not null then 'S' else 'N' end con_td
          from cc_cta_corrientes c, ge_cta_clientes cta, ah_tar_debitos t
         where c.nro_cuenta = cta.nro_cuenta
           and c.nro_cuenta = t.nro_cuenta
           and c.estado in ('A', 'N')
           and cta.relacion = 'P'
           and c.cod_sub_modalidad = 9
           and c.cod_ente is not null
           and t.cod_est_solicitud = 4 --Enviada a Infonet
           and ((trunc(c.fec_insercion) = v_fec_ctacte) OR (trunc(c.fec_insercion) between v_fec_anterior and v_fec_ctacte))
           and not exists(select 1
                            from ge_nom_logistica_tmp log
                           where log.nro_cuenta = c.nro_cuenta
                             and log.cod_estado <> 'A')
      union all
      select fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito) plastico,
             ah.cod_oficina cod_ofi_origen,
             fug_obt_des_submodalidad(ah.cod_modulo,ah.cod_modalidad,ah.cod_sub_modalidad) submodalidad,
             'AH' tipo_cta, ah.denominacion,
             fue_obt_per_ente(ah.cod_ente) cod_per_ente,
             fue_obt_nom_ente(ah.cod_ente) nom_ente,
             fue_obt_dir_principa(fue_obt_per_ente(ah.cod_ente)) dir_ente,
             fue_obt_tel_principa(fue_obt_per_ente(ah.cod_ente)) tel_ente,
             cta.cod_persona cod_persona, ah.nro_cuenta nro_cuenta, t.adherente adherente, t.nro_emision nro_emision,
             (select fue_obt_tip_doc_abreviatura(p.cod_tip_documento) from ba_personas p
               where p.cod_persona = cta.cod_persona) tip_doc,
             fue_obt_nro_doc_persona(cta.cod_persona) nro_doc,
             (select pp.pri_nombre from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pri_nombre,
             (select pp.seg_nombre from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) seg_nombre,
             (select pp.pri_apellido from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pri_apellido,
             (select pp.seg_apellido from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) seg_apellido,
             fue_obt_dir_principa(cta.cod_persona) dir_cliente,
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'C' and rownum = 1) cel_cliente,
             (select b.direccion from ba_direcciones b where b.cod_persona = cta.cod_persona
                 and b.principal = 'N' and rownum = 1) dir_sec_cliente,
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'B' and rownum = 1) tel_cliente,
             fug_obt_dir_mail_per(cta.cod_persona) mail,
             (select pp.fec_nacimiento from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) fec_nacimiento,
             (select pp.cod_sexo from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) sexo,
             (select fue_obt_des_pais(pp.cod_pai_nacionalidad) from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pais,
             (select pp.est_civil from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) est_civil,
             (select 'S' from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona and pp.est_civil = 'B') sep_bienes,
             null, null, null,
             fue_obt_des_oficina(ah.cod_oficina) des_oficina,
             fug_obt_cod_usu_oficial(cta.cod_persona) oficial, ah.fec_apertura fec_apertura,
             (select emp.direc_kit from ge_pag_sue_emp emp where emp.nro_cuenta = ah.nro_cuenta
                 and trunc(emp.fec_insercion) = trunc(ah.fec_insercion)and rownum = 1) destino,
             (select sec.descripcion from ge_sec_contables sec where sec.cod_sec_contable = fug_obt_sec_contable(cta.cod_persona)) sec_econ,
             null, ah.usu_insercion usu_insercion, case when t.cod_ent_procesadora is not null then 'S' else 'N' end con_td
          from ah_cta_vistas ah, ge_cta_clientes cta, ah_tar_debitos t
         where ah.nro_cuenta = cta.nro_cuenta
           and ah.nro_cuenta = t.nro_cuenta
           and ah.estado in ('A', 'N')
           and cta.relacion = 'P'
           and t.cod_est_solicitud = 4 --Enviada a Infonet
           and ah.cod_sub_modalidad = 11
           and ah.cod_ente is not null
           and ((trunc(ah.fec_insercion) = v_fec_ahorros) OR (trunc(ah.fec_insercion) between v_fec_anterior and v_fec_ahorros))
           and not exists(select 1
                            from ge_nom_logistica_tmp log
                           where log.nro_cuenta = ah.nro_cuenta
                             and log.cod_estado <> 'A');

  BEGIN
    -- Abrir archivo
    v_file := UTL_FILE.FOPEN(g_repository, v_name, 'W', 32767);

    --Defino Cabecera
    v_line := 'PLASTICO'||chr(9)||'COD_SUC'||chr(9)||'SUB_MOD_CTA'||chr(9)||'TIPO_CTA'||chr(9)||'NOM_CLIENTE'||chr(9)||
              'COD_PER_ENTE'||chr(9)||'NOM_ENTE'||chr(9)||'DIR_ENTE'||chr(9)||'TEL_ENTE'||chr(9)||'COD_PERSONA'||chr(9)||
              'NRO_CUENTA'||chr(9)||'TIP_DOC'||chr(9)||'NRO_DOC'||chr(9)||'PRI_NOMBRE'||chr(9)||'SEG_NOMBRE'||chr(9)||
              'PRI_APELLIDO'||chr(9)||'SEG_APELLIDO'||chr(9)||'DIR_PRINCIPAL'||chr(9)||'TEL_CELULAR'||chr(9)||
              'DIR_SECUNDARIA'||chr(9)||'TEL_BAJA'||chr(9)||'MAIL'||chr(9)||'FEC_NACIMIENTO'||chr(9)||'SEXO'||chr(9)||
              'PAIS'||chr(9)||'EST_CIVIL'||chr(9)||'SEP_BIENES'||chr(9)||'CONYUGE'||chr(9)||'CONY_TIP_DOC'||chr(9)||
              'CONY_NRO_DOC'||chr(9)||'OFICINA'||chr(9)||'OFICIAL'||chr(9)||'FEC_APERTURA'||chr(9)||'DESTINO'||chr(9)||
              'SEC_ECONOMICO'||chr(9)||'NRO_GUIA'||chr(9)||'USUARIO'||chr(9)||'CON_TDD';
    UTL_FILE.PUT_LINE(v_file, v_line);

    --Definir un cursor for loop que recorre los datos obtenidos
    FOR x IN arc_log LOOP
      --nulo los campos no encontrados
      if x.cod_per_ente like '%Ente no registrado en el sistema%' then x.cod_per_ente := null; end if;
      if x.nom_ente like '%Ente no registrado en el sistema%' then x.nom_ente := null; end if;
      if x.dir_ente like '%Dirección no registrada en el Sistema%' then x.dir_ente := null; end if;
      if x.tel_ente like '%Nro. de Teléfono no registrado en el Sistema%' then x.tel_ente := null; end if;
      if x.dir_cliente like '%Dirección no registrada en el Sistema%' then x.dir_cliente := null; end if;
      if x.pais like '%País no registrado en el Sistema%' then x.pais := null; end if;

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador chr(9))
      v_line := x.plastico||chr(9)||x.cod_ofi_origen||chr(9)||x.submodalidad||chr(9)||x.tipo_cta||chr(9)||x.embozado||chr(9)||
                x.cod_per_ente||chr(9)||x.nom_ente||chr(9)||x.dir_ente||chr(9)||x.tel_ente||chr(9)||x.cod_persona||chr(9)||
                ''''||x.nro_cuenta||chr(9)||x.tip_doc||chr(9)||x.nro_doc||chr(9)||x.pri_nombre||chr(9)||x.seg_nombre||chr(9)||
                x.pri_apellido||chr(9)||x.seg_apellido||chr(9)||x.dir_cliente||chr(9)||''''||x.cel_cliente||chr(9)||
                x.dir_sec_cliente||chr(9)||x.tel_cliente||chr(9)||x.mail||chr(9)||x.fec_nacimiento||chr(9)||x.sexo||chr(9)||
                x.pais||chr(9)||x.est_civil||chr(9)||x.sep_bienes||chr(9)||x.conyugue||chr(9)||x.cony_tip_doc||chr(9)||
                x.cony_nro_doc||chr(9)||x.des_oficina||chr(9)||x.oficial||chr(9)||x.fec_apertura||chr(9)||x.destino||chr(9)||
                x.sec_econ||chr(9)||x.nro_guia||chr(9)||x.usu_insercion||chr(9)||x.con_td;
      UTL_FILE.PUT_LINE(v_file, v_line);
      EXIT WHEN arc_log%NOTFOUND;
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
  END prg_gen_arc_logistica;
/

