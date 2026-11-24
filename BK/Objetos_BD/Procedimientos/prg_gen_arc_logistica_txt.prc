CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ARC_LOGISTICA_TXT IS

    v_fec_ahorros   date := pag_cal.FU_OBT_FEC_ACTUAL(3);
    v_fec_ctacte    date := pag_cal.FU_OBT_FEC_ACTUAL(4);
    v_fec_anterior  date := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(1),7,1);

    v_file   UTL_FILE.FILE_TYPE;
    v_line   VARCHAR2(32767);
    v_name   VARCHAR2(128) := 'ARC_LOGISTICA.TXT'; -- nombre del archivo

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
    
    vg_csv_separador    varchar2(1) := ';'; 
    CURSOR arc_log IS
      select fue_obt_des_refcodes('TIP_TAR_DEBITO',t.tip_tar_debito) plastico,
             c.cod_oficina cod_ofi_origen,
             fug_obt_des_submodalidad(c.cod_modulo,c.cod_modalidad,c.cod_sub_modalidad) submodalidad,
             'CC' tipo_cta,
             REPLACE(replace(replace(replace(translate(c.denominacion,
             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
             'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),vg_csv_separador,'') embozado,
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
             (select to_char(pp.fec_nacimiento,'dd/mm/yyyy') from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) fec_nacimiento,
             (select pp.cod_sexo from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) sexo,
             (select fue_obt_des_pais(pp.cod_pai_nacionalidad) from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pais,
             (select pp.est_civil from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) est_civil,
             (select 'S' from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona and pp.est_civil = 'B') sep_bienes,
             null conyugue, null cony_tip_doc, null cony_nro_doc,
             fue_obt_des_oficina(c.cod_oficina) des_oficina,
             fug_obt_cod_usu_oficial(cta.cod_persona) oficial, to_char(c.fec_apertura,'dd/mm/yyyy') fec_apertura,
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
             'AH' tipo_cta,
             REPLACE(replace(replace(replace(translate(ah.denominacion,
             'ÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙÑ?,+´~-|°ºª¬!"#$%&/()=?¡¿*¨{}^`[]_:;><ÇÃ%@''',
             'AEIOUYAEIOUAEIOUNN'),chr(10),''),chr(13),''),'"',''),vg_csv_separador,''),
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
             --(select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'C' and rownum = 1) cel_cliente,
             (select b.direccion from ba_direcciones b where b.cod_persona = cta.cod_persona
                 and b.principal = 'N' and rownum = 1) dir_sec_cliente,
             (select bb.area||bb.telefono from ba_telefonos bb where bb.cod_persona = cta.cod_persona
                 and bb.tip_linea = 'B' and rownum = 1) tel_cliente,
             fug_obt_dir_mail_per(cta.cod_persona) mail,
             (select to_char(pp.fec_nacimiento,'dd/mm/yyyy') from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) fec_nacimiento,
             (select pp.cod_sexo from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) sexo,
             (select fue_obt_des_pais(pp.cod_pai_nacionalidad) from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) pais,
             (select pp.est_civil from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona) est_civil,
             (select 'S' from ba_per_fisicas pp where pp.cod_persona = cta.cod_persona and pp.est_civil = 'B') sep_bienes,
             null, null, null,
             fue_obt_des_oficina(ah.cod_oficina) des_oficina,
             fug_obt_cod_usu_oficial(cta.cod_persona) oficial, to_char(ah.fec_apertura,'dd/mm/yyyy') fec_apertura,
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
    v_line := 'PLASTICO'||vg_csv_separador||'COD_SUC'||vg_csv_separador||'SUB_MOD_CTA'||vg_csv_separador||'TIPO_CTA'||vg_csv_separador||'NOM_CLIENTE'||vg_csv_separador||
              'COD_PER_ENTE'||vg_csv_separador||'NOM_ENTE'||vg_csv_separador||'DIR_ENTE'||vg_csv_separador||'TEL_ENTE'||vg_csv_separador||'COD_PERSONA'||vg_csv_separador||
              'NRO_CUENTA'||vg_csv_separador||'TIP_DOC'||vg_csv_separador||'NRO_DOC'||vg_csv_separador||'PRI_NOMBRE'||vg_csv_separador||'SEG_NOMBRE'||vg_csv_separador||
              'PRI_APELLIDO'||vg_csv_separador||'SEG_APELLIDO'||vg_csv_separador||'DIR_PRINCIPAL'||vg_csv_separador||'TEL_CELULAR'||vg_csv_separador||             
              'DIR_SECUNDARIA'||vg_csv_separador||'TEL_BAJA'||vg_csv_separador||'MAIL'||vg_csv_separador||'FEC_NACIMIENTO'||vg_csv_separador||'SEXO'||vg_csv_separador||
              'PAIS'||vg_csv_separador||'EST_CIVIL'||vg_csv_separador||'SEP_BIENES'||vg_csv_separador||'CONYUGE'||vg_csv_separador||'CONY_TIP_DOC'||vg_csv_separador||
              'CONY_NRO_DOC'||vg_csv_separador||'OFICINA'||vg_csv_separador||'OFICIAL'||vg_csv_separador||'FEC_APERTURA'||vg_csv_separador||'DESTINO'||vg_csv_separador||
              'SEC_ECONOMICO'||vg_csv_separador||'NRO_GUIA'||vg_csv_separador||'USUARIO'||vg_csv_separador||'CON_TDD';
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

      --Generar la linea, agregando si es necesario, un delimitador de campo (tabulador vg_csv_separador)
      v_line := x.plastico||vg_csv_separador||x.cod_ofi_origen||vg_csv_separador||x.submodalidad||vg_csv_separador||x.tipo_cta||vg_csv_separador||x.embozado||vg_csv_separador||
                x.cod_per_ente||vg_csv_separador||x.nom_ente||vg_csv_separador||x.dir_ente||vg_csv_separador||x.tel_ente||vg_csv_separador||x.cod_persona||vg_csv_separador||
                x.nro_cuenta||vg_csv_separador||x.tip_doc||vg_csv_separador||x.nro_doc||vg_csv_separador||x.pri_nombre||vg_csv_separador||x.seg_nombre||vg_csv_separador||
                x.pri_apellido||vg_csv_separador||x.seg_apellido||vg_csv_separador||x.dir_cliente||vg_csv_separador||to_char(x.cel_cliente)||vg_csv_separador||
                x.dir_sec_cliente||vg_csv_separador||x.tel_cliente||vg_csv_separador||x.mail||vg_csv_separador||x.fec_nacimiento||vg_csv_separador||x.sexo||vg_csv_separador||
                x.pais||vg_csv_separador||x.est_civil||vg_csv_separador||x.sep_bienes||vg_csv_separador||x.conyugue||vg_csv_separador||x.cony_tip_doc||vg_csv_separador||
                x.cony_nro_doc||vg_csv_separador||x.des_oficina||vg_csv_separador||x.oficial||vg_csv_separador||x.fec_apertura||vg_csv_separador||x.destino||vg_csv_separador||
                x.sec_econ||vg_csv_separador||x.nro_guia||vg_csv_separador||x.usu_insercion||vg_csv_separador||x.con_td;
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
  END prg_gen_arc_logistica_txt;
/

