CREATE OR REPLACE PACKAGE BODY IT.pag_pla IS
  v_fec_actual date := pag_cal.fu_obt_fec_actual(1);

  /* Insertar BA_PER_FISICAS */
  FUNCTION fu_ins_ba_per_fisicas(p_cod_persona IN ba_per_fisicas.cod_persona%TYPE,
                                 rp_bperf      IN ba_per_fisicas%ROWTYPE)
    RETURN VARCHAR2 IS
    v_cod_persona ba_personas.cod_persona%TYPE;
  BEGIN
    SELECT cod_persona
      INTO v_cod_persona
      FROM ba_per_fisicas
     WHERE cod_persona = p_cod_persona;
    --- Actualizar
    UPDATE ba_per_fisicas
       SET pri_nombre   = rp_bperf.pri_nombre,
           seg_nombre   = rp_bperf.seg_nombre,
           pri_apellido = rp_bperf.pri_apellido,
           seg_apellido = rp_bperf.seg_apellido,
           fec_nacimiento = nvl(fec_nacimiento, rp_bperf.fec_nacimiento),
           cod_profesion  = rp_bperf.cod_profesion
     WHERE cod_persona = p_cod_persona;
    return 'S';
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        INSERT INTO ba_per_fisicas
          (cod_persona,
           pri_nombre,
           seg_nombre,
           pri_apellido,
           seg_apellido,
           est_civil,
           cod_sexo,
           cod_pai_nacionalidad,
           fec_nacimiento,
           cod_ciu_nacimiento,
           cod_profesion)
        VALUES
          (p_cod_persona,
           rp_bperf.pri_nombre,
           rp_bperf.seg_nombre,
           rp_bperf.pri_apellido,
           rp_bperf.seg_apellido,
           rp_bperf.est_civil,
           rp_bperf.cod_sexo,
           rp_bperf.cod_pai_nacionalidad,
           rp_bperf.fec_nacimiento,
           rp_bperf.cod_ciu_nacimiento,
           rp_bperf.cod_profesion);
        return 'S';
      EXCEPTION
        WHEN OTHERS THEN
          return substr('Error al insertar en BA_PER_FISICAS. ' || SQLERRM ||
                        ' Fecha nacimiento: ' || rp_bperf.fec_nacimiento ||
                        ' Primer Nombre: ' || rp_bperf.pri_nombre ||
                        ' Segundo Nombre: ' || rp_bperf.seg_nombre ||
                        ' Primer apellido: ' || rp_bperf.pri_apellido ||
                        ' Segundo apellido: ' || rp_bperf.seg_apellido ||
                        ' Estado civil: ' || rp_bperf.est_civil ||
                        ' Sexo: ' || rp_bperf.cod_sexo ||
                        ' Nacionalidad: ' || rp_bperf.cod_pai_nacionalidad ||
                        ' Ciudad: ' || rp_bperf.cod_ciu_nacimiento||
                        ' Profesion: ' || rp_bperf.cod_profesion,
                        1,
                        4000);
      END;
  END;

  /* Insertar BA_PER_JURIDICAS */
  FUNCTION fu_ins_ba_per_juridicas(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                   rp_bperj      IN ba_per_juridicas%ROWTYPE)
    RETURN VARCHAR2 IS
    v_cod_persona ba_personas.cod_persona%TYPE;
  BEGIN
    SELECT cod_persona
      INTO v_cod_persona
      FROM ba_per_juridicas
     WHERE cod_persona = p_cod_persona;
    --- Actualizar
    UPDATE ba_per_juridicas
       SET raz_social    = rp_bperj.raz_social,
           nom_comercial = rp_bperj.nom_comercial,
       naturaleza    = rp_bperj.naturaleza
     WHERE cod_persona = p_cod_persona;
    return 'S';
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        INSERT INTO ba_per_juridicas
          (cod_persona, raz_social, nom_comercial, naturaleza)
        VALUES
          (p_cod_persona, rp_bperj.raz_social, rp_bperj.nom_comercial, rp_bperj.naturaleza);
        return 'S';
      EXCEPTION
        WHEN OTHERS THEN
          return 'Error al insertar en BA_PER_JURIDICAS. ' || SQLERRM;
      END;
  END;

  /* Insertar GE_CLIENTES */
  FUNCTION fu_ins_ge_clientes(p_cod_persona IN ba_personas.cod_persona%TYPE)
    RETURN VARCHAR2 IS
    v_existe         varchar2(1);
    v_usu_virtual    ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('USU_VIR_PLATAFORMA'),
                                                                user);
    v_ofi_plataforma ba_oficinas.cod_oficina%type := fug_obt_ofi_usuario(v_usu_virtual);

  BEGIN
    SELECT 'S'
      INTO v_existe
      FROM ge_clientes
     WHERE cod_persona = p_cod_persona;
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        INSERT INTO ge_clientes
          (cod_persona,
           cod_oficina,
           cod_usu_oficial,
           exo_impuestos,
           cli_especial,
           cod_seg_cliente,
           cod_tip_deudor,
           residente,
           cod_departamento,
           tip_extracto,
           cod_sec_contable,
           cli_confidencial)
        VALUES
          (p_cod_persona,
           v_ofi_plataforma, -- Suc. Werking
           v_usu_virtual,
           'N',
           'N',
           '2',
           '2',
           'S',
           '11',
           'C',
           'N',
           'N');
        return 'S';
      EXCEPTION
        WHEN OTHERS THEN
          return substr('Error al insertar en GE_CLIENTES. ' || SQLERRM ||
                        'Cod. Persona ' || p_cod_persona || 'Oficial ' ||
                        v_ofi_plataforma || ' Usuario ' || v_usu_virtual,
                        1,
                        4000);
      END;
  END;

  /* Funcion para obtener pais de direccion */
  FUNCTION fu_obt_cod_pais(p_cod_departamento IN ba_ciudades.cod_departamento%TYPE,
                           p_cod_ciudad       IN ba_ciudades.cod_ciudad%TYPE)
    return number IS
    v_cod_pais ba_ciudades.cod_pais%TYPE;

  BEGIN
    BEGIN
      SELECT cod_pais
        INTO v_cod_pais
        FROM ba_ciudades d
       WHERE d.cod_departamento = p_cod_departamento
         AND d.cod_ciudad = p_cod_ciudad;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_pais := 1;
    END;
    return v_cod_pais;
  EXCEPTION
    WHEN OTHERS THEN
      return 'Error al obtener el PAIS. ' || SQLERRM;
  END;

  /* Procedimiento para insertar direccion de la persona */
  FUNCTION fu_ins_dir_persona(p_cod_persona      IN ba_direcciones.cod_persona%TYPE,
                              p_cod_pais         IN ba_direcciones.cod_pais%TYPE,
                              p_cod_ciudad       IN ba_direcciones.cod_ciudad%TYPE,
                              p_direccion        IN ba_direcciones.direccion%TYPE,
                              p_nro_casa         IN ba_direcciones.numero%TYPE,
                              p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                              p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                              p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                              p_piso             IN ba_direcciones.piso%TYPE,
                              p_edificio         IN ba_direcciones.edificio%TYPE,
                              p_referencias      IN ba_direcciones.observacion%TYPE,
                              p_latitud          IN ba_direcciones.latitud%type default null,
                              p_longitud         IN ba_direcciones.longitud%type default null)
    return varchar2 IS

    v_cod_direccion ba_direcciones.cod_direccion%type;
    v_direccion     ba_direcciones.direccion%TYPE;
    v_cod_pais      ba_direcciones.cod_pais%TYPE;

  BEGIN
    v_cod_direccion := 0;
    BEGIN
      SELECT cod_direccion
        INTO v_cod_direccion
        FROM ba_direcciones d
       WHERE d.cod_persona = p_cod_persona
         AND d.cod_direccion =
             (SELECT MAX(cod_direccion)
                FROM ba_direcciones dd
               WHERE dd.cod_persona = d.cod_persona);
      v_cod_direccion := v_cod_direccion + 1;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_direccion := 1;
    END;

    IF p_cal_secundaria is null THEN
      v_direccion := nvl(p_direccion, 'SIN DIRECCION');
    ELSE
      v_direccion := p_direccion || ', ' || p_cal_secundaria;
    END IF;

    IF p_cod_pais is null THEN
      v_cod_pais := fu_obt_cod_pais(p_cod_departamento, p_cod_ciudad);
    END IF;

    INSERT INTO ba_direcciones
      (cod_persona,
       cod_direccion,
       direccion,
       tipo,
       principal,
       observacion,
       cod_pais,
       cod_ciudad,
       cod_barrio,
       numero,
       cod_departamento,
       piso,
       edificio,
       latitud,
       longitud)
    VALUES
      (p_cod_persona,
       v_cod_direccion,
       v_direccion,
       'P',
       'S',
       'INGRESADO POR PLATAFORMA. ' || p_referencias,
       nvl(p_cod_pais, v_cod_pais),
       p_cod_ciudad,
       p_cod_barrio,
       p_nro_casa,
       p_cod_departamento,
       p_piso,
       p_edificio,
       p_latitud,
       p_longitud);

    return 'S';
    --direccion Laboral

  EXCEPTION
    WHEN OTHERS THEN
      return substr('Error al insertar en BA_DIRECCIONES.' || SQLERRM ||
                    ' Cod.persona: ' || p_cod_persona || ' Direccion: ' ||
                    v_direccion || ' Referencia: ' || p_referencias ||
                    ' Pais: ' || p_cod_pais || ' Ciudad: ' || p_cod_ciudad ||
                    ' Barrio: ' || p_cod_barrio || ' Nro.Casa: ' ||
                    p_nro_casa || ' Departamento: ' || p_cod_departamento ||
                    ' Piso: ' || p_piso || ' Edificio: ' || p_edificio,
                    1,
                    4000);
  END;

   /* Procedimiento para insertar direccion de la persona */
  FUNCTION fu_ins_dir_onb_persona(p_cod_persona      IN ba_direcciones.cod_persona%TYPE,
                                  p_cod_pais_res     IN ba_direcciones.cod_pais%TYPE,
                                  p_cod_ciudad       IN ba_direcciones.cod_ciudad%TYPE,
                                  p_direccion        IN ba_direcciones.direccion%TYPE,
                                  p_nro_casa         IN ba_direcciones.numero%TYPE,
                                  p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                                  p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                                  p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                                  p_piso             IN ba_direcciones.piso%TYPE,
                                  p_edificio         IN ba_direcciones.edificio%TYPE,
                                  p_referencias      IN ba_direcciones.observacion%TYPE,
                                  p_latitud          IN ba_direcciones.latitud%type default null,
                                  p_longitud         IN ba_direcciones.longitud%type default null)
    return varchar2 IS

    v_cod_direccion ba_direcciones.cod_direccion%type;
    v_direccion     ba_direcciones.direccion%TYPE;
    v_cod_pais_res  ba_direcciones.cod_pais%TYPE;

  BEGIN
    v_cod_direccion := 0;
    BEGIN
      SELECT cod_direccion
        INTO v_cod_direccion
        FROM ba_direcciones d
       WHERE d.cod_persona = p_cod_persona
         AND d.cod_direccion =
             (SELECT MAX(cod_direccion)
                FROM ba_direcciones dd
               WHERE dd.cod_persona = d.cod_persona);
      v_cod_direccion := v_cod_direccion + 1;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_direccion := 1;
    END;

    IF p_cal_secundaria is null THEN
      v_direccion := nvl(p_direccion, 'SIN DIRECCION');
    ELSE
      v_direccion := p_direccion || ', ' || p_cal_secundaria;
    END IF;

    IF p_cod_pais_res is null THEN
      v_cod_pais_res := fu_obt_cod_pais(p_cod_departamento, p_cod_ciudad);
    END IF;

    INSERT INTO ba_direcciones
      (cod_persona,
       cod_direccion,
       direccion,
       tipo,
       principal,
       observacion,
       cod_pais,
       cod_ciudad,
       cod_barrio,
       numero,
       cod_departamento,
       piso,
       edificio,
       latitud,
       longitud)
    VALUES
      (p_cod_persona,
       v_cod_direccion,
       v_direccion,
       'P',
       'S',
       'INGRESADO POR PLATAFORMA. ' || p_referencias,
       nvl(p_cod_pais_res, v_cod_pais_res),
       p_cod_ciudad,
       p_cod_barrio,
       p_nro_casa,
       p_cod_departamento,
       p_piso,
       p_edificio,
       p_latitud,
       p_longitud);

    return 'S';
    --direccion Laboral

  EXCEPTION
    WHEN OTHERS THEN
      return substr('Error al insertar en BA_DIRECCIONES.' || SQLERRM ||
                    ' Cod.persona: ' || p_cod_persona || ' Direccion: ' ||
                    v_direccion || ' Referencia: ' || p_referencias ||
                    ' Pais: ' || p_cod_pais_res || ' Ciudad: ' || p_cod_ciudad ||
                    ' Barrio: ' || p_cod_barrio || ' Nro.Casa: ' ||
                    p_nro_casa || ' Departamento: ' || p_cod_departamento ||
                    ' Piso: ' || p_piso || ' Edificio: ' || p_edificio,
                    1,
                    4000);
  END;
 
  /* Procedimiento para insertar telefono de la persona */
  FUNCTION fu_ins_tel_persona(p_cod_persona IN ba_telefonos.cod_persona%TYPE,
                              p_num_celular IN ba_telefonos.telefono%TYPE)
    return varchar2 IS
    v_cod_telefono ba_telefonos.cod_telefono%TYPE := 0;

  BEGIN
    BEGIN
      SELECT cod_telefono
        INTO v_cod_telefono
        FROM ba_telefonos d
       WHERE d.cod_persona = p_cod_persona
         AND d.cod_telefono =
             (SELECT MAX(cod_telefono)
                FROM ba_telefonos dd
               WHERE dd.cod_persona = d.cod_persona);
      v_cod_telefono := v_cod_telefono + 1;

    EXCEPTION
      WHEN no_data_found THEN
        v_cod_telefono := 1;
    END;

    INSERT INTO ba_telefonos
      (cod_persona,
       cod_telefono,
       area,
       telefono,
       interno,
       observacion,
       tipo,
       tip_linea,
       principal)
    VALUES
      (p_cod_persona,
       v_cod_telefono,
       null,
       p_num_celular,
       null,
       'INGRESADO POR PLATAFORMA',
       'P',
       'C',
       'S');
    return 'S';
  EXCEPTION
    WHEN OTHERS THEN
      return substr('Error al insertar BA_TELEFONOS. ' || SQLERRM ||
                    ' Cod.Persona: ' || p_cod_persona || ' Celular: ' ||
                    p_num_celular,
                    1,
                    4000);
  END;

  /*Inserta tarea de WF para los documentos ingresado*/
  FUNCTION fu_ins_ba_per_ima_documentos(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                                        p_ima_documento     in ba_per_ima_documentos.ima_doc%TYPE,
                                        p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%TYPE,
                                        p_fec_vencimiento   in ba_per_ima_documentos.fec_vencimiento%TYPE,
                                        p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE default null,
                                        p_observacion       in ba_per_ima_documentos.observacion%type default null,
                                        p_usu_insercion     in ba_per_ima_documentos.usu_insercion%type default null)
    RETURN varchar2 IS
    v_nro_referencia    ba_per_ima_documentos.nro_referencia%TYPE;
    v_mensaje           varchar2(2000);
    v_error             number;
    v_vigencia          ba_con_doc_checklist.vigencia%TYPE := 0;
    v_observacion       ba_per_ima_documentos.observacion%type;
    v_cod_tip_documento ba_per_ima_documentos.cod_tip_documento%type;
    v_men_error  ge_log_errores.det_error%type;
    v_con_unico         varchar2(1) := 'N';
    v_est_doc           varchar2(1) := 'N';
  BEGIN

    begin
      select val_minimo
        into v_cod_tip_documento
        from ba_cod_referencias
       where dominio = 'TIP_PER_DOCUMENTO'
         and val_maximo = p_cod_tip_documento;
    exception
      when no_data_found then
        RETURN 'Error al obtener equivalente de tipo de documento';
      when others then
        RETURN 'Error al obtener equivalente de tipo de documento' || sqlerrm;
    end;

    BEGIN
      SELECT a.nro_referencia
        INTO v_nro_referencia
        FROM ba_per_ima_documentos a
       WHERE a.cod_persona = p_cod_persona
         AND a.cod_tip_documento = v_cod_tip_documento
         AND a.nro_referencia =
             (SELECT max(b.nro_referencia)
                FROM ba_per_ima_documentos b
               WHERE b.cod_persona = a.cod_persona
                 and b.cod_tip_documento = a.cod_tip_documento);
      v_nro_referencia := v_nro_referencia + 1;
    EXCEPTION
      WHEN no_data_found THEN
        v_nro_referencia := 1;
    END;

    if p_observacion is null then
      v_observacion := 'INGRESADO POR PLATAFORMA';
    else
      v_observacion := p_usu_insercion || '|' || p_observacion;
    end if;
  -- DA-9874
    begin
    select nvl(fug_obt_pardinamico('HAB_CON_UNICO'), 'N')
     into v_con_unico
    from dual;
    end;
    if v_con_unico = 'S' and v_cod_tip_documento = '64' then
      v_est_doc := 'A';
    else
      v_est_doc := 'N';
    end if;
    if nvl(v_cod_tip_documento, 'X') != 'X' and
       nvl(v_nro_referencia, 0) > 0 then
      INSERT INTO ba_per_ima_documentos
        (cod_persona,
         ima_doc,
         fec_escaneo,
         est_doc,
         observacion,
         cod_tip_documento,
         fec_vencimiento,
         nro_referencia,
         fec_emision)
      VALUES
        (p_cod_persona,
         p_ima_documento,
         pag_cal.FU_OBT_FEC_ACTUAL(1),
         v_est_doc,
         v_observacion,
         v_cod_tip_documento,
         p_fec_vencimiento,
         v_nro_referencia,
         p_fec_emision);

      select nvl(max(d.vigencia), 0)
        into v_vigencia
        from ba_con_doc_checklist d
       where d.cod_tip_documento = p_cod_tip_documento;

      update ba_per_doc_checklist p
         set p.fec_emision     = p_fec_emision,
             p.estado          = decode(p_fec_emision, null, 'P', 'V'),
             p.tiene           = decode(p_fec_emision, null, 'N', 'S'),
             p.fec_vencimiento = decode(p_fec_emision,
                                        null,
                                        null,
                                        p_fec_emision + v_vigencia)
       where p.cod_persona = p_cod_persona
         and p.cod_tip_documento = p_cod_tip_documento;

      if sql%notfound then
        pr_ins_checklist(p_cod_persona,
                         v_error,
                         v_mensaje,
                         p_cod_tip_documento,
                         p_fec_emision);
      end if;

      RETURN 'S';
    else
      RETURN 'N';
    end if;
  EXCEPTION
    WHEN OTHERS THEN
      v_men_error := substr('Error al insertar en BA_PER_IMA_DOCUMENTOS ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            2000);
      prg_ins_log_programas('PAG_PLA.FU_INS_BA_PER_IMA_DOCUMENTOS',
                            substr(v_men_error || ' Tip.Doc ' ||
                                   p_cod_tip_documento||' Fec venc '||p_fec_vencimiento||
                                   ' Fec_emision ' ||p_fec_emision,
                                   1,
                                   4000),
                            p_cod_persona);
      RETURN v_men_error;
  END;

  PROCEDURE pr_upd_ba_per_ima_documentos(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                                         p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%type,
                                         p_id_crear          in ba_per_ima_documentos.cod_id_crear%type,
                                         p_url_crear         in ba_per_ima_documentos.url_crear%type,
                                         p_cod_error         out number,
                                         p_men_error         out varchar2,
                                         p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE default null,
                                         p_usu_insercion     in ba_per_ima_documentos.usu_insercion%type default null,
                                         p_est_acuse_web     in ba_per_ima_documentos.est_acuse_web%type default 'N',
                                         p_fec_acuse_web     in ba_per_ima_documentos.fec_acuse_web%type default null
                                         ) IS
    v_nro_referencia    ba_per_ima_documentos.nro_referencia%TYPE;
    v_cod_tip_documento ba_per_ima_documentos.cod_tip_documento%type;
    v_error             number;
    v_mensaje           varchar2(2000);
    v_vigencia          ba_con_doc_checklist.vigencia%TYPE;
    v_con_unico         varchar2(1) := 'N';
    v_est_doc           varchar2(1) := 'N';

  BEGIN
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    p_cod_error := 0;
    p_men_error := 'Operación exitosa';
    begin
      select val_minimo
        into v_cod_tip_documento
        from ba_cod_referencias
       where dominio = 'TIP_PER_DOCUMENTO'
         and val_maximo = p_cod_tip_documento;
    exception
      when no_data_found then
        p_cod_error := 1;
        p_men_error := 'No existe tipo documento ' || p_cod_tip_documento;
      when others then
        p_cod_error := 1;
        p_men_error := substr('Error al recuperar tipo documento ' ||
                              p_cod_tip_documento || ' ' || sqlerrm,
                              1,
                              2000);
    end;
  if nvl(p_cod_error, 0) = 0 then
    -- DA-9874
    begin
      select nvl(fug_obt_pardinamico('HAB_CON_UNICO'), 'N')
         into v_con_unico
      from dual;
    end;
    if v_con_unico = 'S' and v_cod_tip_documento = '64' then
      v_est_doc := 'A';
    else
      v_est_doc := 'N';
    end if;

     begin
      update ba_per_ima_documentos
         set cod_id_crear = p_id_crear, url_crear = p_url_crear,
           est_acuse_web = p_est_acuse_web, fec_acuse_web = p_fec_acuse_web
       where cod_persona = p_cod_persona
         and cod_tip_documento = v_cod_tip_documento
         and cod_id_crear is null;
     exception
     when others then
       p_cod_error := 2;
       p_men_error := 'Error en la actualización ';
     end;

    if  sql%rowcount = 0 then
      BEGIN
        SELECT a.nro_referencia
          INTO v_nro_referencia
          FROM ba_per_ima_documentos a
         WHERE a.cod_persona = p_cod_persona
           AND a.cod_tip_documento = v_cod_tip_documento
           AND a.nro_referencia =
               (SELECT max(b.nro_referencia)
                  FROM ba_per_ima_documentos b
                 WHERE b.cod_persona = a.cod_persona
                   and b.cod_tip_documento = a.cod_tip_documento);
          v_nro_referencia := nvl(v_nro_referencia, 0) + 1;
        EXCEPTION
          WHEN no_data_found THEN
            v_nro_referencia := 1;
        END;
        BEGIN
          INSERT INTO ba_per_ima_documentos
            (cod_persona,
             fec_escaneo,
             est_doc,
             observacion,
             cod_tip_documento,
             cod_id_crear,
             url_crear,
             nro_referencia,
             fec_emision,
             est_acuse_web,
             fec_acuse_web
             )
          VALUES
            (p_cod_persona,
             pag_cal.FU_OBT_FEC_ACTUAL(1),
             v_est_doc,
             p_usu_insercion || '|' || 'INGRESADO POR CREAR',
             v_cod_tip_documento,
             p_id_crear,
             p_url_crear,
             v_nro_referencia,
             p_fec_emision,
             p_est_acuse_web,
             p_fec_acuse_web );
        EXCEPTION
          WHEN dup_val_on_index then

            update ba_per_ima_documentos
               set cod_id_crear = p_id_crear, url_crear = p_url_crear,
                   est_acuse_web = p_est_acuse_web, fec_acuse_web = p_fec_acuse_web
             where cod_persona = p_cod_persona
               and cod_tip_documento = v_cod_tip_documento
               and nvl(cod_id_crear, 'x') = 'x';

            if  sql%rowcount = 0 then
              p_cod_error := 2;
              p_men_error := 'No se pudo actualizar ningun registro del tipo ' ||
                             p_cod_tip_documento;
            end if;
        END;
      end if;

      select nvl(max(d.vigencia), 0)
        into v_vigencia
        from ba_con_doc_checklist d
       where d.cod_tip_documento = p_cod_tip_documento;

      update ba_per_doc_checklist p
         set p.fec_emision     = p_fec_emision,
             p.estado          = decode(p_fec_emision, null, 'P', 'V'),
             p.tiene           = decode(p_fec_emision, null, 'N', 'S'),
             p.fec_vencimiento = decode(p_fec_emision,
                                        null,
                                        null,
                                        p_fec_emision + v_vigencia)
       where p.cod_persona = p_cod_persona
         and p.cod_tip_documento = p_cod_tip_documento;

      if sql%rowcount = 0 then
        pr_ins_checklist(p_cod_persona,
                         v_error,
                         v_mensaje,
                         p_cod_tip_documento,
                         p_fec_emision);
      end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PAG_PLA.PR_UPD_BA_PER_IMA_DOCUMENTOS',
                            substr(p_men_error || ' Tip.Doc: ' ||
                                   p_cod_tip_documento || ' URL: ' ||
                                   p_url_crear || ' crear_id: ' ||
                                   p_id_crear || ' fec_emision: ' ||
                                   p_fec_emision,
                                   1,
                                   4000),
                            p_cod_persona);
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 999;
      p_men_error := substr('Error al actualizar la imagen del documento. ' ||
                            DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace,
                            1,
                            2000);
      prg_ins_log_programas('PAG_PLA.PR_UPD_BA_PER_IMA_DOCUMENTOS',
                            substr(p_men_error || ' Tip.Doc ' ||
                                   p_cod_tip_documento || ' URL ' ||
                                   p_url_crear || ' crear_id ' ||
                                   p_id_crear|| ' fec_emision: ' ||
                                   p_fec_emision,
                                   1,
                                   4000),
                            p_cod_persona);
  END;

  PROCEDURE pr_ins_checklist(p_cod_persona       in ba_per_ima_documentos.cod_persona%TYPE,
                             p_cod_error         out number,
                             p_men_error         out varchar2,
                             p_cod_tip_documento in ba_per_ima_documentos.cod_tip_documento%type DEFAULT null,
                             p_fec_emision       in ba_per_ima_documentos.fec_emision%TYPE DEFAULT null) IS
    cursor doc_checklist is
      select ch.cod_tip_documento, ch.vigencia
        from ba_con_doc_checklist ch
       where ch.cod_tip_documento =
             nvl(p_cod_tip_documento, ch.cod_tip_documento)
         and p_cod_persona is not null
         and not exists
       (select 1
                from ba_per_doc_checklist
               where cod_persona = p_cod_persona
                 and cod_tip_documento = ch.cod_tip_documento);
  BEGIN
    Begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    p_cod_error := 0;

    for c_doc in doc_checklist loop
      begin
        insert into ba_per_doc_checklist
          (cod_persona,
           cod_tip_documento,
           estado,
           fec_vencimiento,
           fec_emision,
           tiene)
        values
          (p_cod_persona,
           c_doc.cod_tip_documento,
           decode(p_fec_emision, null, 'P', 'V'),
           decode(p_fec_emision, null, null, p_fec_emision + c_doc.vigencia),
           p_fec_emision,
           decode(p_fec_emision, null, 'N', 'S'));
      exception
        when dup_val_on_index then
          null;
      end;
    end loop;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 999;
      p_men_error := 'Error al actualizar CheckList de la Persona. ' ||
                     sqlerrm;
      prg_ins_log_programas('PAG_GLO.PR_INS_CHECKLIST',
                            substr(p_men_error, 1, 4000));
  END;

  PROCEDURE pr_act_est_checklist IS
    v_fec_actual ge_calendarios.fec_actual%type := pag_cal.FU_OBT_FEC_ACTUAL(1);
    cursor pers_check_list is
      select p.*
        from ba_per_doc_checklist p, ba_con_doc_checklist d
       where p.cod_tip_documento = d.cod_tip_documento
         and p.estado != 'E'
         and (p.fec_emision + d.vigencia < v_fec_actual or
             p.fec_vencimiento < v_fec_actual);
  BEGIN
    for c_check in pers_check_list loop
      update ba_per_doc_checklist p
         set p.estado = 'E'
       where p.cod_persona = c_check.cod_persona
         and p.cod_tip_documento = c_check.cod_tip_documento;
    end loop;

  EXCEPTION
    WHEN OTHERS THEN
      prg_ins_log_programas('PAG_PLA.PR_ACT_EST_CHECKLIST',
                            substr(sqlerrm, 1, 4000));
  END;

  /*Busca */

  /* Alta Persona */
  PROCEDURE pr_alt_persona(p_tipo              in ba_personas.tipo%type, -- fisica o juridica
                           p_nombres           in ba_personas.nom_completo%type,
                           p_apellidos         in ba_personas.nom_completo%type,
                           p_nro_documento     in ba_personas.nro_documento%type,
                           p_tip_documento     in ba_personas.cod_tip_documento%type,
                           p_est_civil         in ba_per_fisicas.est_civil%type,
                           p_fec_nacimiento    in ba_per_fisicas.fec_nacimiento%type,
                           p_cod_sexo          in ba_per_fisicas.cod_sexo%type,
                           p_fec_vto_documento in ba_personas.fec_vto_documento%type,
                           p_direccion         in ba_direcciones.direccion%type,
                           p_cod_ciudad        in ba_ciudades.cod_ciudad%type,
                           p_cod_pais          in ba_ciudades.cod_pais%type,
                           p_rub_primario      in ba_personas.cod_rub_primario%type,
                           p_num_celular       in ba_telefonos.telefono%type,
                           p_dir_correo        in ba_personas.dir_correo%type,
                           p_est_documento     in varchar2,
                           p_est_pru_vida      in varchar2,
                           p_cod_pai_nac       in ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                           p_cod_ciu_nac       in ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                           p_nro_casa          in ba_direcciones.numero%TYPE,
                           p_cal_secundaria    in ba_direcciones.direccion%TYPE,
                           p_cod_barrio        in ba_direcciones.cod_barrio%TYPE,
                           p_cod_departamento  in ba_direcciones.cod_departamento%TYPE,
                           p_piso              in ba_direcciones.piso%TYPE,
                           p_edificio          in ba_direcciones.edificio%TYPE,
                           p_referencias       in ba_direcciones.observacion%TYPE,
                           p_est_bancarizacion in varchar2,
                           p_usu_plataforma    in varchar2,
                           p_latitud           in ba_direcciones.latitud%TYPE DEFAULT null,
                           p_longitud          in ba_direcciones.longitud%TYPE DEFAULT null,
                           p_fec_emision       in ba_personas.fec_vto_documento%TYPE DEFAULT null,
                           p_est_match_doc     in varchar2,
                           p_es_pep            in varchar2,
                           p_isocr             in varchar2 default null,
                           p_cod_persona       out ba_personas.cod_persona%type,
                           p_est_verificacion  out varchar2,
                           p_cre_productos     out varchar2,
                           p_est_ios_excepcion out varchar2,
                           p_cod_error         out number,
                           p_mensaje           out varchar2)

   IS
    v_per_par_adicional  ba_tab_dat_adicionales.referencia%type;
    v_cod_persona        ba_personas.cod_persona%type;
    r_bpers              ba_personas%ROWTYPE;
    r_bperf              ba_per_fisicas%ROWTYPE;
    r_bperj              ba_per_juridicas%ROWTYPE;
    v_tip_persona        VARCHAR2(3);
    v_des_tip_persona    VARCHAR2(20);
    v_nombre             VARCHAR2(200);
    v_apellido           varchar2(200);
    v_direccion          ge_par_generales.dir_correo%type := fug_obt_pardinamico('DIR_ENV_MAI_ALT_PERSONA');
    v_retorno            varchar2(4000) := null;
    v_inhibido           varchar2(1) := 'N';
    v_edad               number;
    v_existe             number;
    v_exi_mail           varchar2(1);
    v_exi_cel            varchar2(1);
    v_exi_usu            varchar2(1);
    v_num_celular        ba_telefonos.telefono%type;
    v_dir_correo         ba_personas.dir_correo%type;
    v_usu_plataforma     varchar2(50);
    v_cod_error          number(6);
    v_mensaje            varchar2(4000);
    v_log_mensaje        varchar2(4000);
    v_pro_correcto       number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                       0);
    v_fecha              date := pag_Cal.FU_OBT_FEC_ACTUAL(1);
    v_riesgo             varchar2(30);
    v_exi_circuito       varchar2(1);
    v_cod_barrio         ba_barrios.cod_barrio%type;
    v_dir_cumplimiento   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_ENV_MAI_CUMPLIMIENTO');
    v_pri_nombre         ba_per_fisicas.pri_nombre%type;
    v_seg_nombre         ba_per_fisicas.seg_nombre%type;
    v_pri_apellido       ba_per_fisicas.pri_apellido%type;
    v_seg_apellido       ba_per_fisicas.seg_apellido%type;
    v_nom_completo       ba_personas.nom_completo%type;
    v_rub_primario       ge_rub_economicos.cod_rub_economico%type;
    v_es_inhibida        varchar2(1);
    v_cod_cau_alt_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_ALT_RIESGO',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);
    v_cod_cau_med_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_MED_RIESGO',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);

    /*v_cod_cau_pep ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_PEP',
                                                                             null,
                                                                             null,
                                                                             null,
                                                                             null);*/--DA-7917
  v_cod_cau_pep ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('PEP_ONBOARDING',
                                                                          null,
                                                                          null,
                                                                          null,
                                                                          null);

    v_exc_activo  varchar2(1) := fug_obt_pardinamico('ONB_EXCEPCION',
                                                     null,
                                                     null,
                                                     null,
                                                     null);
    v_gen_cir_49  varchar(1) := 'N';
    v_est_civil   varchar2(100);

    v_cod_causa         ge_per_inhibidas.cod_causa%type;
    v_per_existente     number := 0;
    v_fec_vto_documento ba_personas.fec_vto_documento%type;
    v_enc_lista         varchar(1) := 'N';
    cursor c_cir_anteriores(p_cod_persona in ba_personas.cod_persona%type) is
      select w.cod_tip_circuito, w.cod_persona, w.cod_circuito
        from wf_circuitos w
       where estado not in ('C', 'F')
         and cod_tip_circuito in (37, 38, 39, 40, 41, 43, 44)
         and cod_persona = p_cod_persona;
    /* Verifico si el nombre ya existe */

    /* Procedimiento Principal*/
  BEGIN
    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    v_retorno           := null;
    v_inhibido          := 'N';
    v_edad              := trunc((MONTHS_BETWEEN(v_fecha, p_fec_nacimiento) / 12));
    p_est_ios_excepcion := v_exc_activo;
    -- Validar que se hayan ingresado los datos obligatorios de acuerdo al tipo de persona.

    if p_nro_documento is null then
      -- nro_documento
      p_mensaje   := 'Numero de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_tip_documento is null then
      -- tipo de documento
      p_mensaje   := 'Tipo de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_documento is null then
      -- estado de documento
      p_mensaje   := 'Estado de documento no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_pru_vida is null then
      -- estado de prueba de vida
      p_mensaje   := 'Estado de prueba de vida no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_match_doc is null then
      -- estado de prueba de vida
      p_mensaje   := 'Indicador de el indicador de coincidencia de prueba de vida y documento de identidad no puede ser vacio';
      p_cod_error := 3;
      return;
    end if;

    if p_cod_barrio is null then
      v_cod_barrio := fug_obt_pardinamico('COD_BAR_ONBOARDING');
      if v_cod_barrio is null then
        p_mensaje   := 'Barrio por defecto no parametrizado';
        p_cod_error := 4;
      end if;
    else
      v_cod_barrio := p_cod_barrio;
    end if;
    v_per_par_adicional := null;
    if p_num_celular is null and p_tipo = 'F' then
      -- numero de celular
      p_mensaje   := 'Numero de celular no puede ser nulo.';
      p_cod_error := 3;
      return;
    elsif p_num_celular is not null and p_tipo = 'F' then
      BEGIN
        SELECT DISTINCT referencia
          INTO v_per_par_adicional
          FROM ba_tab_dat_adicionales
         WHERE tab_relacion = 'BA_PERSONAS'
           AND val_parametro = p_num_celular
           AND parametro = 'CELULAR_ONBOARDING'
           and rownum = 1;
        IF v_per_par_adicional is not null THEN
          v_log_mensaje := 'El nro celular ' || p_num_celular ||
                           ' ya se encuentra parametrizado en onboarding para la persona ' ||
                           v_per_par_adicional;
          p_mensaje     := 'El nro celular ' || p_num_celular ||
                           ' ya se encuentra parametrizado en onboarding ';
          p_cod_error   := 4;
          if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
            prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                                  v_log_mensaje,
                                  null,
                                  null);
          end if;
          p_cod_persona := v_per_par_adicional;
          return;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN

          v_per_par_adicional := 'N';

        WHEN others then
          p_mensaje     := 'Ocurrio un error al verificar numero celular:  ' ||
                           p_num_celular;
          v_log_mensaje := substr('Ocurrio un error al verificar numero celular:  ' ||
                                  p_num_celular || ' ' || sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      END;
    end if;
    v_per_par_adicional := null;
    if p_dir_correo is null and p_tipo = 'F' then
      -- correo electronico
      p_mensaje   := 'Direccion de correo no puede ser nula.';
      p_cod_error := 3;
      return;
    elsif p_dir_correo is not null and p_tipo = 'F' then
      BEGIN
        SELECT DISTINCT referencia
          INTO v_per_par_adicional
          FROM ba_tab_dat_adicionales
         WHERE tab_relacion = 'BA_PERSONAS'
           AND val_parametro = p_dir_correo
           AND parametro = 'EMAIL_ONBOARDING'
           and rownum = 1;
        IF v_per_par_adicional is not null THEN
          v_log_mensaje := 'El correo ' || p_dir_correo ||
                           ' ya se encuentra parametrizado en onboarding
                             para la persona ' ||
                           v_per_par_adicional;
          p_mensaje     := 'El correo ' || p_dir_correo ||
                           ' ya se encuentra parametrizado en onboarding';
          p_cod_error   := 4;
          if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
            prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                                  v_log_mensaje,
                                  null,
                                  null);
          end if;
          p_cod_persona := v_per_par_adicional;
          return;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          v_per_par_adicional := 'N';
        WHEN others then
          p_mensaje     := 'Ocurrio un error al verificar correo:  ' ||
                           p_dir_correo;
          v_log_mensaje := substr('Ocurrio un error al verificar correo:  ' ||
                                  p_dir_correo || ' ' || sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      END;

    end if;

    if p_est_pru_vida not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_pru_vida ||
                     ' invalido para la prueba de Vida (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_est_match_doc not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_match_doc ||
                     ' invalido (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_est_documento not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_documento ||
                     ' invalido para estado de documento (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_tipo not in ('F', 'M') and p_tipo is not null then
      p_mensaje   := 'Valor ' || p_tipo ||
                     ' invalido para tipo de persona (F: Fisica, J: Juridica).';
      p_cod_error := 4;
    end if;

    if p_rub_primario is not null and nvl(p_cod_error, 0) = 0 then
      BEGIN
        SELECT cod_rub_economico
          INTO v_rub_primario
          FROM ge_rub_economicos e
         WHERE cod_rub_economico =
               (select val_maximo
                  from ba_cod_referencias T
                 where t.dominio = 'ONB_OCUPACIONES'
                   and t.val_minimo = p_rub_primario);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          p_mensaje   := 'No existe rubro primario ' || p_rub_primario;
          p_cod_error := 4;
        WHEN OTHERS THEN
          p_mensaje     := 'Error al verificar rubro primario ' ||
                           p_rub_primario;
          v_log_mensaje := substr('Error al verificar rubro primario ' ||
                                  p_rub_primario || ' ' || sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      END;
    end if;

    --    da-657  control estado civil valido
    if p_est_civil is not null and p_tipo = 'F' then
      -- estado civil
      begin
        select 1
          into v_existe
          from ba_cod_referencias
         where dominio = 'COD_EST_CIVIL'
           and val_minimo = substr(p_est_civil, 1, 1);
        v_est_civil := p_est_civil;
      exception
        when no_data_found then
          v_log_mensaje := 'Estado civil ' || p_est_civil || ' no existe.';
          v_gen_cir_49  := 'S';
          v_est_civil   := 'SOLTERO';
        when others then
          p_mensaje     := 'Error al verificar estado civil. ';
          v_log_mensaje := substr('Error en estado civil. ' || p_est_civil || ' ' ||
                                  sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      end;
    end if;
    if nvl(v_cod_cau_pep, '0') = '0' or
       nvl(v_cod_cau_alt_riesgo, '0') = '0' or
       nvl(v_cod_cau_med_riesgo, '0') = '0' then
       p_mensaje   := 'Verificar no se encuentran configurados los parametros de causales COD_CAU_PEP,COD_CAU_ALT_RIESGO,COD_CAU_MED_RIESGO';
       p_cod_error := 99;
    end if;
    --
    if nvl(p_cod_error, 0) = 0 then
      BEGIN
        SELECT cod_persona
          INTO v_cod_persona
          FROM ba_personas
         WHERE cod_tip_documento = p_tip_documento
           AND nro_documento = trim(p_nro_documento);

        v_exi_cel := null;
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_exi_cel
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = v_cod_persona
             and rownum = 1;

        EXCEPTION
          WHEN no_data_found THEN
            v_exi_cel := 'N';
          WHEN others then
            p_mensaje     := 'Ocurrio un error al verificar el celular onboarding para la persona' ||
                             v_cod_persona;
            v_log_mensaje := substr('Ocurrio un error al verificar el celular onboarding para la persona' ||
                                    v_cod_persona || ' ' || sqlerrm,
                                    1,
                                    4000);
            p_cod_error   := 4;
        END;

        v_exi_mail := null;
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_exi_mail
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = v_cod_persona
             and rownum = 1;

        EXCEPTION
          WHEN no_data_found THEN
            v_exi_mail := 'N';
          WHEN others then
            p_mensaje     := 'Ocurrio un error al verificar email onboarding para la persona:  ' ||
                             v_cod_persona;
            v_log_mensaje := substr('Ocurrio un error al verificar email onboarding para la persona:  ' ||
                                    v_cod_persona || ' ' || sqlerrm,
                                    1,
                                    4000);
            p_cod_error   := 4;
        END;

        v_exi_usu := null;
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_exi_usu
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'GE_CLIENTES'
             AND parametro = 'GEN_COD_USU_PLATAFORMA'
             and referencia = v_cod_persona
             and rownum = 1;

        EXCEPTION
          WHEN no_data_found THEN
            v_exi_usu := 'N';
          WHEN others then
            p_mensaje     := 'Ocurrio un error al verificar el usuario plataforma, para la persona  ' ||
                             v_cod_persona;
            v_log_mensaje := substr('Ocurrio un error al verificar el usuario plataforma, para la persona  ' ||
                                    v_cod_persona || ' ' || sqlerrm,
                                    1,
                                    4000);
            p_cod_error   := 4;
        END;

        IF nvl(v_exi_mail, 'N') = 'N' or nvl(v_exi_cel, 'N') = 'N' or
           nvl(v_exi_usu, 'N') = 'N' THEN
          v_per_par_adicional := 'N';
        ELSIF nvl(v_exi_mail, 'N') = 'S' and nvl(v_exi_cel, 'N') = 'S' and
              nvl(v_exi_usu, 'N') = 'S' then
          v_per_par_adicional := v_cod_persona;
          p_mensaje           := 'Cliente ya esta registrado en onboarding';
          p_cod_error         := 4;
        ELSE
          v_per_par_adicional := v_cod_persona;
        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          v_cod_persona := 'N';
      END;

      IF v_cod_persona = 'N' and nvl(p_cod_error, 0) = 0 THEN
        if p_tipo is null then
          -- tipo de persona
          p_mensaje   := 'Tipo de Persona no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_nombres is null then
          -- nombres
          p_mensaje   := 'Debe ingresar un Nombre.';
          p_cod_error := 3;
          return;
        end if;

        if p_apellidos is null and p_tipo = 'F' then
          -- apellidos
          p_mensaje   := 'Debe ingresar un Apellido.';
          p_cod_error := 3;
          return;
        end if;

        if p_est_civil is null and p_tipo = 'F' then
          -- estado civil
          p_mensaje   := 'Estado civil no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_fec_nacimiento is null and p_tipo = 'F' then
          -- fecha de nacimiento
          p_mensaje   := 'Fecha de nacimiento no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_cod_sexo is null and p_tipo = 'F' then
          -- sexo
          p_mensaje   := 'Sexo no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_direccion is null then
          -- direccion
          p_mensaje   := 'Debe ingresar una direccion.';
          p_cod_error := 3;
          return;
        end if;

        IF p_cod_departamento is null THEN
          -- departamento
          p_mensaje   := 'Departamento no puede ser nulo.';
          p_cod_error := 3;
          return;
        END IF;

        if p_cod_ciudad is null then
          -- ciudad
          p_mensaje   := 'Ciudad no puede ser nula.';
          p_cod_error := 3;
          return;
        end if;

        if p_cod_pai_nac is null and p_tipo = 'F' then
          -- Nacionalidad
          p_mensaje   := 'Nacionalidad no debe de ser nula.';
          p_cod_error := 3;
          return;
        end if;

        IF p_cod_ciu_nac is null and p_tipo = 'F' THEN
          --Ciudad(Lugar) de Nacimiento
          p_mensaje   := 'Lugar de nacimiento no debe de ser nula.';
          p_cod_error := 3;
          return;
        END IF;

        if v_rub_primario is null then
          -- actividad economica
          p_mensaje   := 'Actividad economica no puede ser nula.';
          p_cod_error := 3;
          return;
        end if;
        -- vencimiento documento
        if p_fec_vto_documento is null and p_tipo = 'F' then
          if nvl(v_exc_activo, 'N') = 'S' then
            --contingencia biometria
            v_fec_vto_documento := to_date('01/01/2050', 'dd/mm/yyyy');
          else
            p_mensaje   := 'Vencimiento de documento no puede ser nulo.';
            p_cod_error := 3;
            return;
          end if;
        else
          v_fec_vto_documento := p_fec_vto_documento;
        end if;

        v_nombre                  := upper(TRIM(p_nombres));
        v_apellido                := upper(TRIM(p_apellidos));
        v_tip_persona             := p_tipo;
        r_bpers.nom_completo      := substr(v_nombre || ' ' || v_apellido,
                                            1,
                                            120);
        r_bpers.nro_documento     := upper(TRIM(p_nro_documento));
        r_bpers.fec_vto_documento := v_fec_vto_documento;
        r_bpers.cod_tip_documento := p_tip_documento;
        r_bpers.cod_rub_primario  := v_rub_primario;
        r_bpers.cod_actividad     := fug_obt_cod_actividad(v_rub_primario);
        r_bpers.cod_pais          := nvl(p_cod_pais, p_cod_pai_nac);
        r_bpers.dir_correo        := p_dir_correo;

        IF v_tip_persona = 'F' THEN
          r_bpers.tipo                 := 'F';
          r_bperf.pri_nombre           := fug_obt_nombre(v_nombre, 1);
          r_bperf.pri_apellido         := fug_obt_nombre(v_apellido, 1);
          r_bperf.seg_nombre           := fug_obt_nombre(v_nombre, 2);
          r_bperf.seg_apellido         := fug_obt_nombre(v_apellido, 2);
          r_bperf.est_civil            := substr(v_est_civil, 1, 1); --DA-6274 estado civil
          r_bperf.cod_sexo             := p_cod_sexo;
          r_bperf.fec_nacimiento       := p_fec_nacimiento;
          r_bperf.cod_pai_nacionalidad := p_cod_pai_nac;
          r_bperf.cod_ciu_nacimiento   := p_cod_ciu_nac;
        ELSE
          r_bpers.tipo          := 'J';
          r_bperj.raz_social    := TRIM(upper(substr(r_bpers.nom_completo,
                                                     1,
                                                     120)));
          r_bperj.nom_comercial := TRIM(upper(substr(r_bpers.nom_completo,
                                                     1,
                                                     65)));
        END IF;

        IF (r_bperf.pri_nombre IS NULL) AND r_bpers.tipo = 'F' THEN
          p_mensaje   := 'No se permite valores nulos para Primer Nombre';
          p_cod_error := 3;
          return;
        ELSIF (r_bperf.pri_apellido IS NULL) AND r_bpers.tipo = 'F' THEN
          p_mensaje   := 'No se permite valores nulos para Primer Apellido';
          p_cod_error := 3;
          return;
        ELSIF r_bperj.raz_social IS NULL AND r_bpers.tipo = 'J' THEN
          p_mensaje   := 'No se permite valores nulos para Razon Social';
          p_cod_error := 3;
          return;
        ELSIF r_bperj.nom_comercial IS NULL AND r_bpers.tipo = 'J' THEN
          p_mensaje   := 'No se permite valores nulos para Nombre Comercial';
          p_cod_error := 3;
          return;
        ELSE

          BEGIN
            SELECT cod_persona
              INTO v_cod_persona
              FROM ba_personas
             WHERE cod_tip_documento = p_tip_documento
               AND nro_documento = p_nro_documento;
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_persona := null;
          END;

          IF nvl(v_cod_persona, 'X') = 'X' and nvl(p_cod_error, 0) = 0 THEN
            BEGIN
              --- No existe la persona
              SELECT s_cod_persona.nextval INTO v_cod_persona FROM dual;

              INSERT INTO ba_personas
                (cod_persona,
                 nom_completo,
                 tipo,
                 cod_tip_documento,
                 nro_documento,
                 cod_pais,
                 cod_rub_primario,
                 dir_correo,
                 fec_vto_documento,
                 cod_actividad)
              VALUES
                (v_cod_persona,
                 r_bpers.nom_completo,
                 r_bpers.tipo,
                 r_bpers.cod_tip_documento,
                 r_bpers.nro_documento,
                 r_bpers.cod_pais,
                 r_bpers.cod_rub_primario,
                 r_bpers.dir_correo,
                 r_bpers.fec_vto_documento,
                 r_bpers.cod_actividad);
              v_retorno := 'S';
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje     := 'Ocurrio un error al crear Persona ';
                v_log_mensaje := substr('Ocurrio un error al crear Persona ' ||
                                        SQLERRM || ' Nombre: ' ||
                                        r_bpers.nom_completo || ' Tipo: ' ||
                                        r_bpers.tipo || ' Tipo Doc: ' ||
                                        r_bpers.cod_tip_documento ||
                                        'Pais: ' || r_bpers.cod_pais ||
                                        ' Rub.Primario: ' ||
                                        r_bpers.cod_rub_primario ||
                                        ' Correo: ' || r_bpers.dir_correo ||
                                        ' Fecha vto.doc: ' ||
                                        r_bpers.fec_vto_documento ||
                                        ' Actividad: ' ||
                                        r_bpers.cod_actividad,
                                        1,
                                        4000);
                p_cod_error   := 99;
            END;
          END IF;
          v_retorno := null;
          if nvl(p_cod_error, 0) = 0 then
            IF r_bpers.tipo = 'F' THEN
              v_des_tip_persona := 'fisica';
              v_retorno         := fu_ins_ba_per_fisicas(v_cod_persona,
                                                         r_bperf);
            ELSE
              v_des_tip_persona := 'juridica';
              v_retorno         := fu_ins_ba_per_juridicas(v_cod_persona,
                                                           r_bperj);
            END IF;
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al crear persona ' ||
                               v_des_tip_persona;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            end if;
          end if;

          if nvl(p_cod_error, 0) = 0 and p_dir_correo is not null then

            begin
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 v_cod_persona,
                 'EMAIL_ONBOARDING',
                 p_dir_correo);
            EXCEPTION

              WHEN OTHERS THEN
                p_mensaje     := 'Error al insertar el correo ' ||
                                 p_dir_correo || ' como dato adicional ';
                v_log_mensaje := substr('Error al insertar el correo ' ||
                                        p_dir_correo ||
                                        ' como dato adicional ' || sqlerrm,
                                        1,
                                        4000);
                p_cod_error   := 99;
            END;

          end if;
          v_retorno := null;
          if nvl(p_cod_error, 0) = 0 then
            v_retorno := fu_ins_dir_persona(v_cod_persona,
                                            p_cod_pais,
                                            p_cod_ciudad,
                                            p_direccion,
                                            p_nro_casa,
                                            p_cal_secundaria,
                                            v_cod_barrio,
                                            p_cod_departamento,
                                            p_piso,
                                            p_edificio,
                                            p_referencias,
                                            p_latitud,
                                            p_longitud);
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al guardar direccion ';
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            end if;
          end if;
          v_retorno := null;
          IF p_num_celular is not null and nvl(p_cod_error, 0) = 0 THEN
            v_retorno := fu_ins_tel_persona(v_cod_persona, p_num_celular);
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Error al insertar telefono ' ||
                               p_num_celular;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            else
              BEGIN
                INSERT INTO ba_tab_dat_adicionales
                  (tab_relacion, referencia, parametro, val_parametro)
                VALUES
                  ('BA_PERSONAS',
                   v_cod_persona,
                   'CELULAR_ONBOARDING',
                   p_num_celular);
              EXCEPTION
                WHEN OTHERS THEN
                  if nvl(v_retorno, 'N') = 'S' then
                    p_mensaje     := 'Error al insertar el nro celuldar ' ||
                                     p_num_celular ||
                                     ' como dato adicional ';
                    v_log_mensaje := substr('Error al insertar el nro celuldar ' ||
                                            p_num_celular ||
                                            ' como dato adicional ' ||
                                            sqlerrm,
                                            1,
                                            4000);
                    p_cod_error   := 99;
                  end if;
              END;
            end if;
          END IF;

          if nvl(p_cod_error, 0) = 0 then
            if p_usu_plataforma is not null then
              BEGIN
                INSERT INTO ba_tab_dat_adicionales
                  (tab_relacion, referencia, parametro, val_parametro)
                VALUES
                  ('GE_CLIENTES',
                   v_cod_persona,
                   'GEN_COD_USU_PLATAFORMA',
                   p_usu_plataforma);
              EXCEPTION
                WHEN OTHERS THEN
                  p_mensaje     := 'Error al insertar usuario plataforma ' ||
                                   p_usu_plataforma ||
                                   ' como dato adicional ';
                  v_log_mensaje := substr('Error al insertar usuario plataforma ' ||
                                          p_usu_plataforma ||
                                          ' como dato adicional ' ||
                                          sqlerrm,
                                          1,
                                          4000);
                  p_cod_error   := 99;
              END;
            end if;
          end if;
        end if;
      ELSE
        p_cod_persona := v_cod_persona;
        IF nvl(p_cod_error, 0) = 0 THEN
          IF p_tipo = 'F' THEN
            ---
             v_nombre                     := upper(TRIM(p_nombres));
             v_apellido                   := upper(TRIM(p_apellidos));
             r_bperf.pri_nombre           := fug_obt_nombre(v_nombre, 1);
             r_bperf.pri_apellido         := fug_obt_nombre(v_apellido, 1);
             r_bperf.seg_nombre           := fug_obt_nombre(v_nombre, 2);
             r_bperf.seg_apellido         := fug_obt_nombre(v_apellido, 2);
             r_bperf.fec_nacimiento       := p_fec_nacimiento;
            ---
            v_des_tip_persona := 'fisica';
            v_retorno         := fu_ins_ba_per_fisicas(v_cod_persona,
                                                       r_bperf);
          END IF;
          if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al actualizar persona '|| v_des_tip_persona;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
          end if;
          v_existe := null;
          --verifico si ya tiene productos activos
          begin
            select 1
              into v_existe
              from ge_cta_clientes c
              left outer join ah_cta_vistas v
                on c.nro_cuenta = v.nro_cuenta
              left outer join pr_cta_prestamos p
                on p.nro_cuenta = c.nro_cuenta
              left outer join ta_cta_tarjetas t
                on c.nro_cuenta = t.nro_cuenta
             where c.cod_persona = v_cod_persona
               and c.relacion = 'P'
               and (v.estado not in ('C', 'P') or p.estado != 'N' or
                   t.estado != 'C');
          exception
            when no_data_found then
              v_existe := 0;
            when too_many_rows then
              v_existe := 1;
            when others then
              p_cod_error   := 99;
              p_mensaje     := 'Error al verificar productos activos de la persona ' ||
                               v_cod_persona;
              v_log_mensaje := substr('Error al verificar productos activos de la persona ' ||
                                      v_cod_persona || ' - ' || sqlerrm,
                                      1,
                                      4000);
          end;

          --Si la persona existe y no tiene productos activos entonces actualizar Email
          --Teléfono Dirección Profesión DA-4820
          if nvl(v_existe, 999) = 0 and nvl(p_cod_error, 0) = 0 then
            pr_act_dat_persona(v_cod_persona,
                               v_rub_primario,
                               p_direccion,
                               p_cod_pais,
                               p_cod_ciudad,
                               p_nro_casa,
                               p_cal_secundaria,
                               p_cod_barrio,
                               p_cod_departamento,
                               p_piso,
                               p_edificio,
                               p_referencias,
                               p_num_celular,
                               p_dir_correo,
                               p_latitud,
                               p_longitud,
                               v_cod_error,
                               v_log_mensaje);

            if nvl(v_cod_error, 0) != 0 then
              p_cod_error := 99;
              p_mensaje   := 'Error al actualizar datos de la persona ' ||
                             v_cod_persona;
            end if;
          end if;
          ---Flujo de persona existente
          IF nvl(v_cod_persona, 'X') != 'N' and
             nvl(v_per_par_adicional, 'X') != 'N' THEN
            v_per_existente := 1;
          ELSIF v_per_par_adicional = 'N' and
                nvl(v_cod_persona, 'X') != 'N' THEN
            /*Persona existente sin parametros onboarding*/
            v_per_existente := 1;
            if v_exi_mail = 'N' then
              v_dir_correo := p_dir_correo;
            else
              v_dir_correo := null;
            end if;
            if v_exi_cel = 'N' then
              v_num_celular := p_num_celular;
            else
              v_num_celular := null;
            end if;
            if v_exi_usu = 'N' then
              v_usu_plataforma := p_usu_plataforma;
            else
              v_usu_plataforma := null;
            end if;
            v_cod_error := null;
            IF nvl(p_cod_error, 0) = 0 then
              pr_ins_con_onboarding(v_cod_persona,
                                    v_dir_correo,
                                    v_num_celular,
                                    v_usu_plataforma,
                                    v_cod_error,
                                    v_log_mensaje);
              if nvl(v_cod_error, 0) != 0 then
                p_mensaje   := 'Error al insertar parametro onboarding. Cod Error: ' ||
                               v_cod_error;
                p_cod_error := 99;
              end if;
            END IF;
          END IF;
        END IF;
      END IF;

      v_retorno := null;
      if nvl(p_cod_error, 0) = 0 then
        if nvl(p_isocr, 'N') = 'S' then
          begin
            insert into ba_per_dat_adicionales
              (cod_persona, parametro, val_parametro)
            values
              (v_cod_persona, 'ONB_CON_OCR', p_isocr);
          exception
            when others then
              p_mensaje     := 'Error al insertar parametro adicional de la persona';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al insertar parametro adicional de la persona ' ||
                                      sqlerrm,
                                      1,
                                      4000);
          end;
          if nvl(p_cod_error, 0) = 0 then
            --if paw_cir.fu_ini_circuito(52, v_cod_persona, v_cod_persona) <> 0 then
            if paw_cir.fu_ini_circuito(37, v_cod_persona, v_cod_persona) <> 0 then
              p_mensaje     := 'Error al iniciar el Circuito de Verificación de lectura OCR';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al iniciar el Circuito de Verificación de lectura OCR ' ||
                                      paw_cir.G_MSJ_ERROR,
                                      1,
                                      4000);

            else
              p_est_verificacion := 'P';
            end if;
          end if;
        end if;
        /*Circuito de contingencia*/
        if nvl(v_exc_activo, 'N') = 'S' then
          if paw_cir.fu_ini_circuito(45, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Documentos';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Documentos ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          end if;
        end if;
        /*Circuito verificacion de estado civil en c.i.DA-6274*/
        if nvl(v_gen_cir_49, 'N') = 'S' then
          if paw_cir.fu_ini_circuito(49, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion del estado civil en c.i.';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion del estado civil en c.i. ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          end if;
        end if;
        if p_est_documento = 'N' and nvl(v_exc_activo, 'N') = 'N' then
          if paw_cir.fu_ini_circuito(37, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Imagen subida por la persona';
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Imagen subida por la persona ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
            p_cod_error   := 99;
          else
            p_est_verificacion := 'P';
          end if;
        elsif p_est_documento = 'V' then
          --cedula frente
          v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                            null,
                                                            125,
                                                            v_fec_vto_documento,
                                                            null,
                                                            null);
          if nvl(v_retorno, 'N') = 'S' then
            --cedula reverso
            v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                              null,
                                                              126,
                                                              v_fec_vto_documento,
                                                              null,
                                                              null);
          end if;
          if nvl(v_retorno, 'N') != 'S' then
            p_mensaje     := 'Error al insertar el registro de la imagen para la persona ';
            v_log_mensaje := nvl(v_retorno, p_mensaje);
            p_cod_error   := 99;
          end if;
        end if;
        -- end if;
      end if;
      -- end  if;
      begin
        select f.pri_nombre,
               f.seg_nombre,
               f.pri_apellido,
               f.seg_apellido,
               p.nom_completo
          into v_pri_nombre,
               v_seg_nombre,
               v_pri_apellido,
               v_seg_apellido,
               v_nom_completo
          from ba_per_fisicas f, ba_personas p
         where f.cod_persona = v_cod_persona
           and f.cod_persona = p.cod_persona;
      exception
        when no_data_found then
          v_pri_nombre   := null;
          v_pri_apellido := null;
      end;

      -- Retorna el tipo de Lista (OFAC, WORLDCHECK, SEPRELAD, etc) en el cual se encuentra un nombre parecido al
      v_inhibido := null;
      v_retorno  := null;
      if nvl(p_cod_error, 0) = 0 and
         (v_pri_nombre is not null and v_pri_apellido is not null) then
        v_cod_error := null;
        v_retorno   := null;

        if nvl(fug_cau_inh_por_nombre(v_nom_completo, null), 'X') = 'X' then
          -- Si la persona no tiene coincidencia el campo EST_VERIFICACION debe ser Sin Coincidencias.
          it.prg_per_par_listas(v_pri_nombre,
                                v_seg_nombre,
                                v_pri_apellido,
                                v_seg_apellido,
                                v_cod_error,
                                v_mensaje);

          if nvl(v_cod_error, 0) != 0 then

            -- Se inhibe a la persona si posee coincidencia
            v_inhibido := fu_inh_persona(v_cod_persona);
            if v_inhibido = 'S' then
              v_retorno := 'S';
            else
              p_mensaje     := 'Error al inhibir persona';
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            end if;

            if paw_cir.fu_ini_circuito(38, v_cod_persona, v_cod_persona) <> 0 and
               nvl(p_cod_error, 0) = 0 then
              p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Persona con coincidencia';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Persona con coincidencia ' ||
                                      paw_cir.G_MSJ_ERROR,
                                      1,
                                      4000);
            elsif nvl(p_cod_error, 0) = 0 then
              -- Si la persona tiene una coincidencia el campo EST_VERIFICACION debe ser
              p_est_verificacion := 'P';
              v_enc_lista        := 'S';
            end if;

            -- cod_tip_circuito = 5 -- el 5 es cuando se encuentra como coincidencia cargando desde el itgf
                                    -- el 38 es cuando se encuentra coincidencia desde el proceso de onboarding
            -- DA-6809
         if paw_cir.fu_ini_circuito(5, v_cod_persona, v_cod_persona) <> 0 and
               nvl(p_cod_error, 0) = 0 then
              p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Persona con coincidencia';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Persona con coincidencia ' ||
                                      paw_cir.G_MSJ_ERROR,
                                      1,
                                      4000);
            elsif nvl(p_cod_error, 0) = 0 then
              -- Si la persona tiene una coincidencia el campo EST_VERIFICACION debe ser
              p_est_verificacion := 'P';
              v_enc_lista:='S';
            end if;
          end if;

        else
          -- Se inhibe a la persona si posee coincidencia
          v_inhibido := fu_inh_persona(v_cod_persona);
          if v_inhibido = 'S' then
            v_retorno := 'S';
          else
            p_mensaje     := 'Error al inhibir a la persona.';
            v_log_mensaje := nvl(v_retorno, p_mensaje);
            p_cod_error   := 99;
          end if;
          -- Si la persona tiene una coincidencia el campo EST_VERIFICACION debe ser
          -- En Verificacion y generar un WF

          if paw_cir.fu_ini_circuito(38, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Persona con coincidencia';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Persona con coincidencia ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          elsif nvl(p_cod_error, 0) = 0 then
            p_est_verificacion := 'P';
            v_enc_lista:='S';
          end if;



            -- cod_tip_circuito = 5 -- el 5 es cuando se encuentra como coincidencia cargando desde el itgf
                                    -- el 38 es cuando se encuentra coincidencia desde el proceso de onboarding
            -- DA-6809
          if paw_cir.fu_ini_circuito(5, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Persona con coincidencia';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Persona con coincidencia ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          elsif nvl(p_cod_error, 0) = 0 then
            p_est_verificacion := 'P';
            v_enc_lista        := 'S';
          end if;

          end if;
        end if;
      end if;
  --  end if;

    --Se solicita verificacion de prueba de vida
    --cod_tip_documento 126 en ba_cod_referencias dominio tip_per_documento
    v_retorno := null;
    if nvl(p_cod_error, 0) = 0 then
      if p_est_pru_vida = 'N' and nvl(v_exc_activo, 'N') = 'N' then
        if paw_cir.fu_ini_circuito(39, v_cod_persona, v_cod_persona) <> 0 then
          p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Prueba de vida';
          p_cod_error   := 99;
          v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Prueba de vida ' ||
                                  paw_cir.G_MSJ_ERROR,
                                  1,
                                  4000);

        else
          p_est_verificacion := 'P';
        end if;
      elsif p_est_pru_vida = 'V' then
        v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                          null,
                                                          127,
                                                          v_fec_vto_documento,
                                                          null,
                                                          null);
        if nvl(v_retorno, 'N') != 'S' then
          p_mensaje     := 'Error al insertar registro para imagen de prueba de vida';
          v_log_mensaje := nvl(v_retorno, p_mensaje);
          p_cod_error   := 99;
        end if;
      end if;
    end if;

    /*if p_est_match_doc = 'N' and nvl(p_cod_error, 0) = 0 and
       nvl(v_exc_activo, 'N') = 'N' then
      if paw_cir.fu_ini_circuito(40, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje   := 'Error al iniciar el Circuito de Verificacion de macheo prueba de vida con CI';
        p_cod_error := 99;
        v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de macheo prueba de vida con CI '||paw_cir.G_MSJ_ERROR,1,4000);
      else
        p_est_verificacion := 'P';
      end if;
    end if;*/

    if v_fec_vto_documento < v_fec_actual and nvl(p_cod_error, 0) = 0 then
      if paw_cir.fu_ini_circuito(41, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Documento vencido';
        p_cod_error   := 99;
        v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Documento vencido ' ||
                                paw_cir.G_MSJ_ERROR,
                                1,
                                4000);
      else
        p_est_verificacion := 'P';
      end if;

    end if;

    if nvl(v_cod_persona, 'X') != 'X' and nvl(p_cod_error, 0) = 0 then
      begin
        select p.cod_causa
          into v_cod_causa
          from ge_per_inhibidas p
         where p.cod_persona = v_cod_persona
           and p.cod_causa in (v_cod_cau_alt_riesgo, v_cod_cau_med_riesgo)
           and p.estado = 'I'
           and rownum = 1;
        v_es_inhibida := 'S';
      exception
        when no_data_found then
          v_es_inhibida := 'N';
        when too_many_rows then
          v_es_inhibida := 'S';
        when others then
          p_mensaje     := 'Error al verificar si la persona es cliente alto/medio riesgo';
          p_cod_error   := 99;
          v_log_mensaje := substr('Error al verificar si la persona es cliente alto/medio riesgo ' ||
                                  sqlerrm,
                                  1,
                                  4000);
      end;

      IF nvl(v_es_inhibida, 'N') = 'S' and nvl(p_cod_error, 0) = 0 THEN
        if paw_cir.fu_ini_circuito(43, v_cod_persona, v_cod_persona) <> 0 then
          p_mensaje     := 'Error al iniciar el Circuito de Cliente Alto/Medio Riesgo';
          p_cod_error   := 99;
          v_log_mensaje := 'Error al iniciar el Circuito de Cliente Alto/Medio Riesgo ' ||
                           paw_cir.G_MSJ_ERROR;
        elsif nvl(p_cod_error, 0) = 0 then
          p_est_verificacion := 'P';
        end if;
      end if;
    end if;
    v_retorno := null;
    IF nvl(p_es_pep, 'N') = 'S' and nvl(p_cod_error, 0) = 0 THEN
      v_inhibido := fu_inh_persona(v_cod_persona, v_cod_cau_pep);
      if v_inhibido = 'S' then
        v_retorno := 'S';
      else
        p_mensaje     := 'Error al inhibir persona ';
        p_cod_error   := 99;
        v_log_mensaje := nvl(v_retorno, p_mensaje);
      end if;

      if paw_cir.fu_ini_circuito(44, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje     := 'Error al iniciar el Circuito de Cliente PEP';
        p_cod_error   := 99;
        v_log_mensaje := substr('Error al iniciar el Circuito de Cliente PEP ' ||
                                paw_cir.G_MSJ_ERROR,
                                1,
                                4000);
      elsif nvl(p_cod_error, 0) = 0 then
        if nvl(v_enc_lista, 'N') = 'S' then
          --si creó circuito 38 por encontrarse coincidencias
          p_est_verificacion := 'P';
      end if;
    end if;
  end if;
    /*Circuito de menor de edad*/
    IF v_edad < nvl(to_number(fug_obt_pardinamico('BA_MAY_EDAD')), 0) and
       nvl(p_cod_error, 0) = 0 THEN
      if paw_cir.fu_ini_circuito(42, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje   := 'Error al iniciar el Circuito de Menor de edad';
        p_cod_error := 99;
      else
        for rec in c_cir_anteriores(v_cod_persona) loop
          if paw_cir.FU_CAN_CIR_PENDIENTES(rec.cod_tip_circuito,
                                           rec.cod_persona) <> 0 then
            p_mensaje     := 'Error al cancelar circuito tipo: ' ||
                             rec.cod_tip_circuito;
            v_log_mensaje := substr('Error al cancelar circuito tipo: ' ||
                                    rec.cod_tip_circuito || ' ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
            p_cod_error   := 99;
            exit;
          end if;
          if rec.cod_tip_circuito in (44, 38) then
            update ge_per_inhibidas i
               set i.estado = 'D'
             where i.estado = 'I'
               and i.cod_causa in
                   (v_cod_cau_pep,
                    fug_obt_pardinamico('COD_CAU_BLO_ALT_PER'))
               and i.cod_persona = rec.cod_persona;
          end if;

        end loop;
        if nvl(p_cod_error, 0) = 0 then
          p_est_verificacion := 'P';
        end if;
      end if;
    END IF;
    if nvl(p_cod_error, 0) = 0 then
      -- En el caso que ambos estados no sean validos, el campo EST_VERIFICACION,
      -- debe ser Sin Verificacion.
      if nvl(p_est_verificacion, 'X') = 'P' then

        update ba_personas
           set est_verificacion = 'N' -- Sin verificacion
         where cod_persona = v_cod_persona;
        p_cre_productos := 'N'; --No se crea producto
      elsif ((p_est_documento = 'V' and p_est_pru_vida = 'V' and
            p_est_match_doc = 'V') or nvl(p_est_verificacion, 'X') = 'V') then
        -- Si los dos estados son validos. el campo EST_VERIFICACION debe ser Verificado..
        update ba_personas
           set est_verificacion = 'V' -- Verificado
         where cod_persona = v_cod_persona;
        p_est_verificacion := 'V';
        p_cre_productos    := 'S';
      elsif nvl(v_enc_lista, 'N') = 'N' and nvl(p_es_pep, 'N') = 'S' then
        --si creó circuito 38 por encontrarse coincidencias
        update ba_personas
           set est_verificacion = 'V' -- Verificado
         where cod_persona = v_cod_persona;
        p_cre_productos    := 'S'; --Si crea producto
        p_est_verificacion := 'V';
      elsif nvl(v_exc_activo, 'N') = 'S' and
            (p_est_documento = 'N' or p_est_pru_vida = 'N' or
             p_est_match_doc = 'N') then

        update ba_personas
           set est_verificacion = 'V'
         where cod_persona = v_cod_persona;
        p_est_verificacion := 'V';
        p_cre_productos    := 'S';
      end if;
    end if;
    v_cod_error := null;
    v_mensaje   := null;
    if nvl(p_cod_error, 0) = 0 and v_cod_persona != 'N' and
       p_dir_correo is not null and p_est_verificacion = 'P' then
      pr_env_not_onboarding(v_cod_persona,
                            p_nro_documento,
                            p_dir_correo,
                            fug_obt_pardinamico('ONB_MAI_BIE_TEMPLATE'),
                            v_cod_error,
                            v_mensaje);
    end if;

    if nvl(p_cod_error, 0) != 0 and
       nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      p_cod_persona := null;
      prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                            substr('Documento Nro. ' || p_nro_documento ||
                                   ' Error: ' ||
                                   nvl(v_log_mensaje, p_mensaje),
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
      rollback;
    elsif nvl(v_log_mensaje, 'X') != 'X' then
      prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                            substr('Documento Nro. ' || p_nro_documento ||
                                   ' Error: ' || v_log_mensaje,
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;

    if v_per_existente = 1 and nvl(p_cod_error, 0) = 0 then
      -- retorna con el codigo de error si la persona ya existe y no debe hacer rollback
      p_cod_error := v_per_existente;
      p_mensaje   := 'Persona existente';
    end if;

    if v_cod_persona != 'N' and nvl(p_cod_error, 0) = 0 then
      p_cod_persona := v_cod_persona;
      p_mensaje     := null;
      p_cod_error   := 0;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      v_log_mensaje := substr('Error al procesar el alta de la persona ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      p_cod_error   := 99;
      p_mensaje     := 'Ocurrio un error inesperado durante el proceso del alta de persona';
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                              substr('Documento Nro. ' || p_nro_documento ||
                                     ' Error: ' ||
                                     nvl(v_log_mensaje, p_mensaje),
                                     1,
                                     4000),
                              null,
                              null);
      end if;
      rollback;
  END;

  /* Inhibir Persona */
  FUNCTION fu_inh_persona(p_cod_persona IN ge_per_inhibidas.cod_persona%type,
                          p_cod_causa   IN ge_per_inhibidas.cod_causa%type default null)
    RETURN VARCHAR2 IS
    v_nro_orden      number := 0;
    v_fec_inhibicion date := pag_cal.fu_obt_fec_actual(1);
    v_referencia     ge_per_inhibidas.referencia%type;
  BEGIN
    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    select nvl(max(nro_orden), 0) + 1
      into v_nro_orden
      from ge_per_inhibidas
     where cod_persona = p_cod_persona;

    /*    if p_cod_causa = nvl(fug_obt_pardinamico('COD_CAU_PEP'), '0') then
      v_referencia := 'ONB_PEP';
    else
      v_referencia := null;
    end if;*/ --DA-7917

    if p_cod_causa = nvl(fug_obt_pardinamico('PEP_ONBOARDING'), '0') then
      v_referencia := 'PEP_ONBOARDING';
    else
      v_referencia := null;
    end if;

    INSERT INTO ge_per_inhibidas
      (cod_persona,
       nro_orden,
       cod_causa,
       fec_inicio,
       fec_vencimiento,
       origen,
       cod_banco,
       nro_cta_inhibida,
       mto_multa,
       referencia,
       detalle,
       estado,
       cod_campana)
    VALUES
      (p_cod_persona,
       v_nro_orden,
       nvl(p_cod_causa, fug_obt_pardinamico('COD_CAU_BLO_ALT_PER')),
       v_fec_inhibicion,
       v_fec_inhibicion + 365,
       'Persona no cumple con lo requerido.',
       null,
       null,
       null,
       v_referencia,
       'No cumple con lo requerido en el Alta de Persona.',
       'I',
       null);
    return 'S';
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
        INSERT INTO ge_per_inhibidas
          (cod_persona,
           nro_orden,
           cod_causa,
           fec_inicio,
           fec_vencimiento,
           origen,
           cod_banco,
           nro_cta_inhibida,
           mto_multa,
           referencia,
           detalle,
           estado,
           cod_campana)
        VALUES
          (p_cod_persona,
           v_nro_orden + 1,
           fug_obt_pardinamico('COD_CAU_BLO_ALT_PER'),
           v_fec_inhibicion,
           v_fec_inhibicion + 365,
           'Persona no cumple con lo requerido.',
           null,
           null,
           null,
           null,
           'Bloqueo - Persona que no cumpla con lo requerido en el Alta de Persona.',
           null,
           null);
        return 'S';
      EXCEPTION
        WHEN OTHERS THEN
          Return substr('Error al insertar en ge_per_inhibidas. ' ||
                        SQLERRM || ' Cod.Persona: ' || p_cod_persona ||
                        ' Nro. Orden: ' || v_nro_orden || ' Fecha: ' ||
                        v_fec_inhibicion,
                        1,
                        4000);
      END;
  END;

  /* Modificacion de datos de la persona*/
  FUNCTION fu_mod_persona(p_cod_persona   IN ba_personas.cod_persona%TYPE,
                          p_tipo          IN ba_personas.tipo%TYPE,
                          p_profesion     IN ba_per_fisicas.cod_profesion%TYPE,
                          p_niv_educacion IN ba_per_fisicas.cod_niv_estudio%TYPE,
                          --Datos complejos
                          p_dir_correo         IN ba_personas.dir_correo%TYPE,
                          p_nro_documento      IN ba_personas.nro_documento%TYPE,
                          p_fec_vto_documento  IN ba_personas.fec_vto_documento%TYPE,
                          p_cod_rub_primario   IN ba_personas.cod_rub_primario%TYPE,
                          p_cod_rub_secundario IN ba_personas.cod_rub_secundario%TYPE,
                          p_cod_rub_terciaria  IN ba_personas.cod_rub_terciario%TYPE,
                          p_cod_tip_documento  IN ba_personas.cod_tip_documento%TYPE,
                          p_es_contribuyente   IN ba_personas.tip_iva%TYPE,
                          --Persona fisica
                          p_nombres              IN ba_personas.nom_completo%TYPE,
                          p_apellidos            IN ba_personas.nom_completo%TYPE,
                          p_est_civil            IN ba_per_fisicas.est_civil%TYPE,
                          p_fec_nacimiento       IN ba_per_fisicas.fec_nacimiento%TYPE,
                          p_cod_ciu_nacimiento   IN ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                          p_cod_pai_nacionalidad IN ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                          p_cod_sexo             IN ba_per_fisicas.cod_sexo%TYPE)
    return varchar2 is
    v_cod_retorno  varchar2(4) := null;
    v_retorno      varchar2(100) := null;
    v_niv_estudios varchar2(1);
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    --
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      IF p_tipo = 'F' THEN
        --Update ba_personas
        IF p_dir_correo IS NOT NULL or p_nro_documento IS NOT NULL OR
           p_fec_vto_documento IS NOT NULL OR
           p_cod_rub_primario IS NOT NULL or
           p_cod_rub_secundario IS NOT NULL OR
           p_cod_rub_terciaria IS NOT NULL OR
           p_cod_tip_documento IS NOT NULL or
           p_es_contribuyente IS NOT NULL THEN
          UPDATE ba_personas p
             SET p.dir_correo         = nvl(p_dir_correo, p.dir_correo),
                 p.nro_documento      = nvl(p_nro_documento, p.nro_documento),
                 p.fec_vto_documento  = nvl(p_fec_vto_documento,
                                            p.fec_vto_documento),
                 p.cod_rub_primario   = nvl(p_cod_rub_primario,
                                            p.cod_rub_primario),
                 p.cod_rub_secundario = nvl(p_cod_rub_secundario,
                                            p.cod_rub_secundario),
                 p.cod_rub_terciario  = nvl(p_cod_rub_terciaria,
                                            p.cod_rub_terciario),
                 p.cod_tip_documento  = nvl(p_cod_tip_documento,
                                            p.cod_tip_documento),
                 p.tip_iva            = nvl(p_es_contribuyente, p.tip_iva)
           WHERE p.cod_persona = p_cod_persona;
          IF SQL%NOTFOUND THEN
            v_cod_retorno := 2001;
            v_retorno     := v_cod_retorno ||
                             '- No se encontraron datos de la persona.';
          ELSE
            v_cod_retorno := 0000;
            v_retorno     := v_cod_retorno ||
                             '- Actualizacion realizada con exito.';
          END IF;
        END IF;
        IF v_cod_retorno = 0000 THEN
          IF p_profesion is not null or p_niv_educacion is not null THEN
            BEGIN
              SELECT 'S'
                INTO v_niv_estudios
                FROM ba_niv_estudios a
               WHERE a.cod_niv_estudio = p_niv_educacion;
            EXCEPTION
              WHEN NO_DATA_FOUND THEN
                v_cod_retorno := 2001;
                v_retorno     := v_cod_retorno ||
                                 '- Codigo de Estudio no valido.';
            END;
            IF v_cod_retorno = 0000 THEN
              --Update ba_per_fisicas
              BEGIN
                UPDATE ba_per_fisicas
                   SET cod_profesion   = nvl(p_profesion, cod_profesion),
                       cod_niv_estudio = nvl(p_niv_educacion,
                                             cod_niv_estudio)
                 WHERE cod_persona = p_cod_persona;
                IF SQL%NOTFOUND THEN
                  v_cod_retorno := 2001;
                  v_retorno     := v_cod_retorno ||
                                   '- No se encontraron datos de la persona.';
                ELSE
                  v_cod_retorno := 0000;
                  v_retorno     := v_cod_retorno ||
                                   '- Actualizacion realizada con exito.';
                END IF;
              EXCEPTION
                WHEN OTHERS THEN
                  v_cod_retorno := 2001;
                  v_retorno     := v_cod_retorno ||
                                   '- No se pueden actualizar datos profesionales de la persona.';
              END;
            END IF;
          END IF;
        END IF;
        IF v_cod_retorno = 0000 THEN
          IF p_nombres is not null OR p_apellidos is not null OR
             p_est_civil is not null OR p_fec_nacimiento is not null OR
             p_cod_ciu_nacimiento is not null OR
             p_cod_pai_nacionalidad is not null OR p_cod_sexo is not null THEN
            --Update ba_per_fisicas
            UPDATE ba_per_fisicas f
               SET f.pri_nombre           = nvl(fug_obt_nombre(p_nombres, 1),
                                                f.pri_nombre),
                   f.seg_nombre           = nvl(fug_obt_nombre(p_nombres, 2),
                                                f.seg_nombre),
                   f.pri_apellido         = nvl(fug_obt_nombre(p_apellidos,
                                                               1),
                                                f.pri_apellido),
                   f.seg_apellido         = nvl(fug_obt_nombre(p_apellidos,
                                                               2),
                                                f.seg_apellido),
                   f.est_civil            = nvl(p_est_civil, f.est_civil),
                   f.fec_nacimiento       = nvl(p_fec_nacimiento,
                                                f.fec_nacimiento),
                   f.cod_ciu_nacimiento   = nvl(p_cod_ciu_nacimiento,
                                                f.cod_ciu_nacimiento),
                   f.cod_pai_nacionalidad = nvl(p_cod_pai_nacionalidad,
                                                f.cod_pai_nacionalidad),
                   f.cod_sexo             = nvl(p_cod_sexo, f.cod_sexo)
             where f.cod_persona = p_cod_persona;
            IF SQL%NOTFOUND THEN
              v_cod_retorno := 2001;
              v_retorno     := v_cod_retorno ||
                               '- No se encontraron datos de la persona.';
            ELSE
              v_cod_retorno := 0000;
              v_retorno     := v_cod_retorno ||
                               '- Actualizacion realizada con exito.';
            END IF;
          END IF;
        END IF;
      END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriende. Intentar mas adelante.';
    END IF;
    return v_retorno;
  END;

  /* Modificacion de datos de direcciones de la persona*/
  FUNCTION fu_mod_dir_persona(p_cod_persona      IN ba_personas.cod_persona%TYPE,
                              p_cod_direccion    IN ba_direcciones.cod_direccion%TYPE,
                              p_tipo             IN ba_direcciones.tipo%TYPE,
                              p_pri_calle        IN ba_direcciones.direccion%TYPE,
                              p_sec_calle        IN ba_direcciones.direccion%TYPE,
                              p_cod_pais         IN ba_direcciones.cod_pais%TYPE,
                              p_cod_ciudad       IN ba_direcciones.cod_ciudad%TYPE,
                              p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                              p_referencia       IN ba_direcciones.observacion%TYPE,
                              p_numero           IN ba_direcciones.numero%TYPE,
                              p_departamento     IN ba_direcciones.departamento%TYPE,
                              p_piso             IN ba_direcciones.piso%TYPE,
                              p_edificio         IN ba_direcciones.edificio%TYPE,
                              p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                             p_zon_geografica    in varchar2
                              /*p_zon_geografica   IN ba_direcciones.zon_geografica%TYPE*/)
    return varchar2 IS
    v_cod_retorno number;
    v_retorno     varchar2(100) := null;
    --
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      UPDATE ba_direcciones d
         SET d.tipo             = p_tipo,
             d.direccion        = p_pri_calle || ', ' || p_sec_calle,
             d.cod_pais         = p_cod_pais,
             d.cod_ciudad       = p_cod_ciudad,
             d.cod_departamento = p_cod_departamento,
             d.cod_barrio       = p_cod_barrio,
             --d.zon_geografica   = p_zon_geografica,
             d.observacion      = p_referencia,
             d.numero           = p_numero,
             d.departamento     = p_departamento,
             d.edificio         = p_edificio,
             d.piso             = p_piso
       WHERE cod_persona = p_cod_persona
         AND cod_direccion = p_cod_direccion;
      IF SQL%NOTFOUND THEN
        v_cod_retorno := 2002;
        v_retorno     := v_cod_retorno ||
                         '- No se encontraron datos de la direccion de la persona.';
      ELSE
        v_cod_retorno := 0000;
        v_retorno     := v_cod_retorno ||
                         '- Actualizacion realizada con exito.';
      END IF;
      -- END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriende. Intentar mas adelante.';
    END IF;
    return v_retorno;
  END;

  /* Modificacion de datos de telefonos de la persona*/
  FUNCTION fu_mod_tel_persona(p_cod_persona  IN ba_telefonos.cod_persona%TYPE,
                              p_tipo         IN ba_telefonos.tipo%TYPE,
                              p_tip_linea    IN ba_telefonos.tip_linea%TYPE,
                              p_telefono     IN ba_telefonos.telefono%TYPE,
                              p_principal    IN ba_telefonos.principal%TYPE,
                              p_area         IN ba_telefonos.area%TYPE,
                              p_interno      IN ba_telefonos.interno%TYPE,
                              p_cod_telefono IN ba_telefonos.cod_telefono%TYPE)
    return varchar2 IS
    v_cod_retorno number;
    v_retorno     varchar2(100) := null;
    --
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      update ba_telefonos t
         set t.tipo      = p_tipo,
             t.tip_linea = p_tip_linea,
             t.telefono  = p_telefono,
             t.principal = p_principal,
             t.area      = p_area,
             t.interno   = p_interno
       where t.cod_persona = p_cod_persona
         and t.cod_telefono = p_cod_telefono;
      IF SQL%NOTFOUND THEN
        v_cod_retorno := 2003;
        v_retorno     := v_cod_retorno ||
                         '- No se encontraron datos del telefono de la persona.';
      ELSE
        v_cod_retorno := 0000;
        v_retorno     := v_cod_retorno ||
                         '- Actualizacion realizada con exito.';
      END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriende. Intentar mas adelante.';
    END IF;
    return v_retorno;
  END;

  /* Modificacion de datos laborales de la persona */
  FUNCTION fu_mod_lab_persona(p_cod_persona   IN cr_inf_laborales.cod_persona%TYPE,
                              p_nro_secuencia IN cr_inf_laborales.nro_secuencia%TYPE,
                              p_tip_cargo     IN cr_inf_laborales.tip_cargo%TYPE,
                              p_lug_trabajo   IN cr_inf_laborales.lug_trabajo%TYPE,
                              p_fec_ingreso   IN cr_inf_laborales.fec_ingreso%TYPE,
                              p_cod_moneda    IN cr_inf_laborales.cod_moneda%TYPE,
                              p_tip_empleo    IN cr_inf_laborales.tip_empleo%TYPE)
    return varchar2 IS
    v_cod_retorno number;
    v_retorno     varchar2(100) := null;
    v_tip_empleo  cr_inf_laborales.tip_empleo%TYPE;
    v_tip_cargo   cr_inf_laborales.tip_cargo%TYPE;

  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      IF p_tip_cargo is not null OR p_lug_trabajo is not null OR
         p_fec_ingreso is not null OR p_cod_moneda is not null OR
         p_tip_empleo is not null THEN
        BEGIN
          SELECT 00000
            INTO v_cod_retorno
            FROM ba_cod_referencias b
           WHERE b.dominio = 'TIP_CARGO'
             AND b.val_minimo = p_tip_cargo;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_retorno := 2004;
            v_retorno     := v_cod_retorno || '- Tipo de Cargo invalido.';
        END;
        --
        BEGIN
          SELECT 00000
            INTO v_cod_retorno
            FROM ba_cod_referencias b
           WHERE b.dominio = 'TIP_EMPLEO'
             AND b.val_minimo = p_tip_empleo;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_retorno := 2004;
            v_retorno     := v_cod_retorno || '- Tipo de Empleo invalido';
        END;

        IF nvl(v_cod_retorno, 0) = 0000 then
          BEGIN
            UPDATE cr_inf_laborales l
               SET l.tip_cargo   = p_tip_cargo,
                   l.lug_trabajo = nvl(p_lug_trabajo, l.lug_trabajo),
                   l.fec_ingreso = nvl(to_date(p_fec_ingreso, 'DD/MM/RRRR'),
                                       l.fec_ingreso),
                   l.cod_moneda  = nvl(p_cod_moneda, l.cod_moneda),
                   l.tip_empleo  = nvl(p_tip_empleo, l.tip_empleo)
             WHERE l.cod_persona = p_cod_persona
               AND l.nro_secuencia = p_nro_secuencia;
            --
            IF SQL%NOTFOUND THEN
              insert into cr_inf_laborales
                (cod_persona,
                 nro_secuencia,
                 lug_trabajo,
                 fec_ingreso,
                 cod_moneda,
                 tip_empleo)
              values
                (p_cod_persona,
                 p_nro_secuencia,
                 p_lug_trabajo,
                 to_date(p_fec_ingreso, 'DD/MM/RRRR'),
                 p_cod_moneda,
                 p_tip_empleo);
              v_cod_retorno := 0000;
              v_retorno     := v_cod_retorno ||
                               '- Insercion realizada con exito.';
            ELSE
              v_cod_retorno := 0000;
              v_retorno     := v_cod_retorno ||
                               '- Actualizacion realizada con exito.';
            END IF;
          EXCEPTION
            WHEN dup_val_on_index then
              v_cod_retorno := 2016;
              v_retorno     := v_cod_retorno ||
                               '- Error. Al actualizar por duplicacion de datos. ';

          END;
        END IF;
      END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriendo. Intentar mas tarde.';
    END IF;
    return v_retorno;
  END;

  /*Modificacion de datos de referencias */
  FUNCTION fu_mod_ref_persona(P_COD_PERSONA    IN CR_REF_COMERCIALES.COD_PERSONA%TYPE,
                              P_TIP_REFERENCIA IN CR_REF_COMERCIALES.TIP_REFERENCIA%TYPE,
                              P_NRO_SECUENCIA  IN CR_REF_COMERCIALES.NRO_SECUENCIA%TYPE,
                              P_DES_ENTIDAD    IN CR_REF_COMERCIALES.DES_ENTIDAD%TYPE,
                              --                              P_COD_TIP_CUENTA  IN CR_REF_COMERCIALES.COD_TIP_CUENTA%TYPE,
                              P_NRO_CUENTA IN CR_REF_COMERCIALES.NRO_CUENTA%TYPE)
    return varchar2 is
    v_cod_retorno number;
    v_retorno     varchar2(100) := null;
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      IF P_TIP_REFERENCIA = 'C' THEN
        UPDATE cr_ref_comerciales c
           SET c.des_entidad = P_DES_ENTIDAD
         WHERE c.cod_persona = p_cod_persona
           AND c.nro_secuencia = p_nro_secuencia
           AND c.tip_referencia = p_tip_referencia;
        IF SQL%NOTFOUND THEN
          v_cod_retorno := 2010;
          v_retorno     := v_cod_retorno ||
                           '- No se encuentran datos de referencia comercial de la persona.';
        ELSE
          v_cod_retorno := 0000;
          v_retorno     := v_cod_retorno ||
                           '- Actualizacion realizada con exito.';
        END IF;
      ELSIF P_TIP_REFERENCIA = 'B' THEN
        UPDATE cr_ref_comerciales b
           SET b.des_entidad = P_DES_ENTIDAD,
               --b.cod_tip_cuenta  = P_COD_TIP_CUENTA,
               b.nro_cuenta = P_NRO_CUENTA
         WHERE b.cod_persona = p_cod_persona
           AND b.nro_secuencia = p_nro_secuencia
           AND b.tip_referencia = p_tip_referencia;
        IF SQL%NOTFOUND THEN
          v_cod_retorno := 2011;
          v_retorno     := v_cod_retorno ||
                           '- No se encuentran datos de referencia bancaria de la persona.';
        ELSE
          v_cod_retorno := 0000;
          v_retorno     := v_cod_retorno ||
                           '- Actualizacion realizada con exito.';
        END IF;
      ELSE
        UPDATE cr_ref_comerciales t
           SET --t.cod_tip_cuenta  = P_COD_TIP_CUENTA,
               t.nro_cuenta = P_NRO_CUENTA,
               t.des_entidad = P_DES_ENTIDAD
         WHERE t.cod_persona = p_cod_persona
           AND t.nro_secuencia = p_nro_secuencia
           AND t.tip_referencia = p_tip_referencia;
        IF SQL%NOTFOUND THEN
          v_cod_retorno := 2012;
          v_retorno     := v_cod_retorno ||
                           '- No se encuentran datos en referencias de Tarjetas de la persona.';
        ELSE
          v_cod_retorno := 0000;
          v_retorno     := v_cod_retorno ||
                           '- Actualizacion realizada con exito.';
        END IF;
      END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriendo. Intentar mas tarde.';
    END IF;
    return v_retorno;
  END;

  /* Modificacion de datos de vinculos */
  FUNCTION fu_mod_vin_persona(p_cod_persona     IN ba_vinculos.cod_persona%TYPE,
                              p_cod_per_vinculo IN ba_vinculos.cod_per_vinculo%TYPE,
                              p_cod_per_vin_ant IN ba_vinculos.cod_per_vinculo%TYPE,
                              p_tipo            IN ba_vinculos.tipo%TYPE,
                              p_fec_vencimiento IN ba_vinculos.fec_vencimiento%TYPE)
    return varchar2 IS
    v_cod_retorno NUMBER;
    v_retorno     varchar2(10000) := null;
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      IF p_cod_per_vinculo <> p_cod_per_vin_ant THEN
        UPDATE ba_vinculos v
           SET v.cod_per_vinculo = p_cod_per_vinculo,
               v.tipo            = p_tipo,
               v.fec_vencimiento = p_fec_vencimiento
         WHERE v.cod_persona = p_cod_persona
           AND v.cod_per_vinculo = p_cod_per_vin_ant;
        IF SQL%NOTFOUND THEN
          v_cod_retorno := 2013;
          v_retorno     := v_cod_retorno ||
                           '- Error. Al actualizar los datos de vinculo de la persona. ' ||
                           SQLERRM;
        ELSE
          v_cod_retorno := 0000;
          v_retorno     := v_cod_retorno ||
                           '- Actualizacion realizada con exito.';
        END IF;
      ELSE
        UPDATE ba_vinculos v
           SET v.tipo = p_tipo, v.fec_vencimiento = p_fec_vencimiento
         WHERE v.cod_persona = p_cod_persona
           AND v.cod_per_vinculo = p_cod_per_vinculo;
        IF SQL%NOTFOUND THEN
          v_cod_retorno := 2013;
          v_retorno     := v_cod_retorno ||
                           '- Error. Al actualizar los datos de vinculo de la persona. ';
        ELSE
          v_cod_retorno := 0000;
          v_retorno     := v_cod_retorno ||
                           '- Actualizacion realizada con exito.';
        END IF;
      END IF;
    ELSE
      v_cod_retorno := 9999;
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriendo. Intentar mas tarde.';
    END IF;
    return v_retorno;
  END;

  /* Modificacion de datos de Ingresos y Egresos*/
  FUNCTION fu_mod_ing_egr_per(p_cod_persona  IN cr_per_ing_egresos.cod_persona%TYPE,
                              p_cod_concepto IN cr_per_ing_egresos.cod_concepto%TYPE,
                              p_cod_con_ant  IN cr_per_ing_egresos.cod_concepto%TYPE,
                              p_ing_egreso   IN cr_per_ing_egresos.ing_egreso%TYPE,
                              p_importe      IN cr_per_ing_egresos.importe%TYPE)
    return varchar2 IS
    v_cod_retorno NUMBER;
    v_retorno     varchar2(100) := null;
  BEGIN
    BEGIN
      pre_ini_aplicacion;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    IF pae_cnf.fu_obt_est_modulo(1) = 2 THEN
      IF p_ing_egreso = 'I' THEN
        BEGIN
          SELECT 0000
            INTO v_cod_retorno
            FROM CR_CON_ING_EGR
           WHERE CR_CON_ING_EGR.TIPO = p_ing_egreso
             AND COD_CONCEPTO = p_cod_concepto;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_retorno := 2014;
            v_retorno     := v_cod_retorno ||
                             '- Error. El tipo de concepto no corresponde a Ingresos. ';
        END;
        IF v_cod_retorno = 0000 THEN
          BEGIN
            UPDATE cr_per_ing_egresos i
               SET i.cod_concepto = p_cod_concepto,
                   i.ing_egreso   = p_ing_egreso,
                   i.importe      = p_importe
             WHERE i.cod_persona = p_cod_persona
               AND i.cod_concepto = p_cod_con_ant;
            --
            IF SQL%NOTFOUND THEN
              insert into cr_per_ing_egresos
                (cod_persona, cod_concepto, ing_egreso, importe)
              values
                (p_cod_persona, p_cod_concepto, p_ing_egreso, p_importe);
              v_cod_retorno := '000';
              v_retorno     := v_cod_retorno ||
                               '- Insercion realizada con exito.';
            ELSE
              v_cod_retorno := '000';
              v_retorno     := v_cod_retorno ||
                               '- Actualizacion realizada con exito.';
            END IF;
          EXCEPTION
            when dup_val_on_index then
              v_cod_retorno := 2016;
              v_retorno     := v_cod_retorno ||
                               '- Error. Al actualizar por duplicacion de datos. ';
          END;
        END IF;
      ELSE
        BEGIN
          SELECT 0000
            INTO v_cod_retorno
            FROM CR_CON_ING_EGR
           WHERE CR_CON_ING_EGR.TIPO = p_ing_egreso
             AND COD_CONCEPTO = p_cod_concepto;
        EXCEPTION
          WHEN no_data_found THEN
            v_cod_retorno := 2016;
            v_retorno     := v_cod_retorno ||
                             '- Error. El tipo de concepto no corresponde a Egresos. ';
        END;
        IF v_cod_retorno = 0000 THEN
          BEGIN
            UPDATE cr_per_ing_egresos i
               SET i.cod_concepto = p_cod_concepto,
                   i.ing_egreso   = p_ing_egreso,
                   i.importe      = p_importe
             WHERE i.cod_persona = p_cod_persona
               AND i.cod_concepto = p_cod_con_ant;
            --
            IF SQL%NOTFOUND THEN
              insert into cr_per_ing_egresos
                (cod_persona, cod_concepto, ing_egreso, importe)
              values
                (p_cod_persona, p_cod_concepto, p_ing_egreso, p_importe);
              v_cod_retorno := '000';
              v_retorno     := v_cod_retorno ||
                               '- Insercion realizada con exito.';
            ELSE
              v_cod_retorno := '000';
              v_retorno     := v_cod_retorno ||
                               '- Actualizacion realizada con exito.';
            END IF;
          EXCEPTION
            when dup_val_on_index then
              v_cod_retorno := 2016;
              v_retorno     := v_cod_retorno ||
                               '- Error. Al actualizar por duplicacion de datos. ';

          END;
        END IF;
      END IF;
    ELSE
      v_cod_retorno := '999';
      v_retorno     := v_cod_retorno ||
                       '- Proceso de cierre corriendo. Intentar mas tarde.';
    END IF;
    return v_retorno;
  END;
  Function fu_ins_tra_contacto(p_cod_persona      in ge_con_clientes.cod_persona%type,
                               p_nro_cta_contacto in ge_con_clientes.nro_cta_contacto%type,
                               p_alias            in ge_con_clientes.alias%type,
                               p_nombre           in ge_con_clientes.nombre%type,
                               p_apellido         in ge_con_clientes.apellido%type,
                               p_tip_documento    in ge_con_clientes.tip_documento%type,
                               p_nro_documento    in ge_con_clientes.nro_documento%type,
                               p_nro_celular      in ge_con_clientes.nro_celular%type,
                               p_dir_correo       in ge_con_clientes.dir_correo%type,
                               p_cod_ente         in ge_con_clientes.cod_ente%type,
                               p_cod_moneda       in ge_con_clientes.cod_moneda%type)
    return varchar2 is
    v_retorno varchar(4000);
    v_existe  varchar2(1);
  Begin
    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if p_cod_persona is null then
      v_retorno := 'Debe ingresar codigo de persona';
    end if;
    if p_nro_cta_contacto is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar nro de cuenta del contacto';
    end if;
    if p_nombre is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar el nombre del contacto';
    end if;
    if p_apellido is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar el apellido del contacto';
    end if;
    if p_tip_documento is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar el tipo de documento del contacto';
    end if;
    if p_nro_documento is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar el numero de documento del contacto';
    end if;
    if p_cod_ente is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar el codigo de entidad del contacto';
    end if;
    if p_cod_moneda is null and nvl(v_retorno, 'x') = 'x' then
      v_retorno := 'Debe ingresar la moneda de la cuenta del contacto';
    end if;
    if p_nro_cta_contacto is not null and nvl(v_retorno, 'x') = 'x' then
      begin
        select 'S'
          into v_existe
          from ge_con_clientes
         where cod_persona = p_cod_persona
           and nro_cta_contacto = p_nro_cta_contacto
           and nro_documento = p_nro_documento
           and tip_documento = p_tip_documento
           and cod_ente = p_cod_ente;
        if nvl(v_existe, 'N') = 'S' then
          v_retorno := 'La cuenta ' || p_nro_cta_contacto ||
                       ' ya se encuentra registrada';
        end if;
      exception
        when no_data_found then
          v_retorno := null;
        when others then
          v_retorno := 'Error al verificar el numero de cuenta ' ||
                       p_nro_cta_contacto;
      end;
    end if;
    v_existe := null;
    if p_tip_documento is not null and nvl(v_retorno, 'x') = 'x' then
      begin
        select 'S'
          into v_existe
          from ba_tip_documentos d
         where d.cod_tip_documento = p_tip_documento;
      exception
        when no_data_found then
          v_retorno := 'El tipo de documento ' || p_tip_documento ||
                       ' no existe en el sistema';
        when others then
          v_retorno := substr('Ocurrio un error al verificar tipo de documento ' ||
                              sqlerrm,
                              1,
                              4000);
      end;
    end if;
    v_existe := null;
    if p_cod_ente is not null and nvl(v_retorno, 'x') = 'x' then
      begin
        select 'S'
          into v_existe
          from gv_snp_participantes p
         where cod_banco = p_cod_ente;
      exception
        when no_data_found then
          begin
            select 'S'
              into v_existe
              from gv_snp_participantes p
             where p.cod_ente = p_cod_ente;
          exception
            when no_data_found then
              v_retorno := 'Codigo de ente ' || p_cod_ente || ' no existe';
            when others then
              v_retorno := substr('Ocurrio un error al verificar codigo de ente ' ||
                                  sqlerrm,
                                  1,
                                  4000);
          end;
        when others then
          v_retorno := substr('Ocurrio un error al verificar codigo de ente ' ||
                              sqlerrm,
                              1,
                              4000);
      end;
    end if;
    v_existe := null;
    if p_cod_moneda is not null and nvl(v_retorno, 'x') = 'x' then
      begin
        select 'S'
          into v_existe
          from ba_monedas m
         where m.cod_moneda = p_cod_moneda;
      exception
        when no_data_found then
          v_retorno := 'La moneda ' || p_cod_moneda ||
                       ' no existe en el sistema';
        when others then
          v_retorno := substr('Ocurrio un error al verificar moneda ' ||
                              sqlerrm,
                              1,
                              4000);
      end;
    end if;
    if nvl(v_retorno, 'x') = 'x' then
      Begin
        insert into ge_con_clientes
          (cod_persona,
           nro_cta_contacto,
           alias,
           nombre,
           apellido,
           tip_documento,
           nro_documento,
           nro_celular,
           dir_correo,
           cod_ente,
           cod_moneda)
        values
          (p_cod_persona,
           p_nro_cta_contacto,
           p_alias,
           p_nombre,
           p_apellido,
           p_tip_documento,
           p_nro_documento,
           p_nro_celular,
           p_dir_correo,
           p_cod_ente,
           p_cod_moneda);
        v_retorno := 'S';
      exception
        when others then
          v_retorno := substr('Ocurrió un error inesperado al agregar contacto ' ||
                              sqlerrm,
                              1,
                              4000);
      end;
    end if;
    return v_retorno;
  end;
  procedure pr_ins_con_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2) is
    v_existe varchar2(1);
  begin
    if p_cod_persona is null then
      p_mensaje   := 'El codigo persona no puede ser nulo ';
      p_cod_error := 1;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_nro_celular is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND val_parametro = p_nro_celular
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
          IF nvl(v_existe, 'N') = 'S' THEN
            p_mensaje   := 'El nro celular ' || p_nro_celular ||
                           ' ya se encuentra parametrizado en onboarding ';
            p_cod_error := 1;

          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 p_cod_persona,
                 'CELULAR_ONBOARDING',
                 p_nro_celular);
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje   := substr('Error al insertar el nro celular ' ||
                                      p_nro_celular ||
                                      ' como dato adicional ' || sqlerrm,
                                      1,
                                      4000);
                p_cod_error := 2;
            END;
          WHEN others then
            p_mensaje   := substr('Ocurrio un error al verificar numero celular:  ' ||
                                  p_nro_celular || ' ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := 2;
        END;
      end if;
    end if;

    if nvl(p_cod_error, 0) = 0 then
      if p_correo is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND val_parametro = p_correo
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
          IF nvl(v_existe, 'N') = 'S' THEN
            p_mensaje   := 'El nro correo ' || p_correo ||
                           ' ya se encuentra parametrizado en onboarding ';
            p_cod_error := 1;

          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 p_cod_persona,
                 'EMAIL_ONBOARDING',
                 p_correo);
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje   := substr('Error al insertar el correo ' ||
                                      p_correo || ' como dato adicional ' ||
                                      sqlerrm,
                                      1,
                                      4000);
                p_cod_error := 3;
            END;
          WHEN others then

            p_mensaje   := substr('Ocurrio un error al verificar correo:  ' ||
                                  p_correo || ' ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := 2;
        END;
      end if;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_usu_plataforma is not null and nvl(p_cod_error, 0) = 0 then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'GE_CLIENTES'
             AND val_parametro = p_usu_plataforma
             AND parametro = 'GEN_COD_USU_PLATAFORMA'
             and referencia = p_cod_persona
             and rownum = 1;
          IF nvl(v_existe, 'N') = 'S' THEN
            p_mensaje   := 'El usuario plataforma ' || p_usu_plataforma ||
                           ' ya se encuentra parametrizado en onboarding ';
            p_cod_error := 1;

          END IF;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('GE_CLIENTES',
                 p_cod_persona,
                 'GEN_COD_USU_PLATAFORMA',
                 p_usu_plataforma);
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje   := substr('Error al insertar el usuario plataforma ' ||
                                      p_usu_plataforma ||
                                      ' como dato adicional ' || sqlerrm,
                                      1,
                                      4000);
                p_cod_error := 3;
            END;
          WHEN others then
            p_mensaje   := substr('Ocurrio un error al verificar usuario plataforma:  ' ||
                                  p_usu_plataforma || ' - ' || sqlerrm,
                                  1,
                                  4000);
            p_cod_error := 2;
        END;

      end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then

      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                              p_mensaje,
                              p_cod_persona,
                              null);
      end if;
    end if;
  exception
    when others then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_PERSONA',
                              substr(sqlerrm || ' Correo: ' || p_correo ||
                                     ' Celular: ' || p_nro_celular ||
                                     ' Usuario: ' || p_usu_plataforma,
                                     1,
                                     4000),
                              p_cod_persona,
                              null);
      end if;
  end pr_ins_con_onboarding;
  procedure pr_env_not_onboarding(p_cod_persona   in ba_personas.cod_persona%type,
                                  p_nro_documento in ba_personas.nro_documento%type,
                                  p_correo        in ba_tab_dat_adicionales.val_parametro%type,
                                  p_tip_producto  in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error     out number,
                                  p_mensaje       out varchar2) is
    v_nro_documento ba_personas.nro_documento%type;
    v_apodo         tm_per_lis_blancas.apodo%type;
  begin

    if p_nro_documento is null then
      begin
        select p.nro_documento
          into v_nro_documento
          from ba_personas p
         where p.cod_persona = p_cod_persona
           and rownum = 1;
      exception
        when no_data_found then
          p_cod_error := 1;
          p_mensaje   := 'No se existe la persona: ' || p_cod_persona;
      end;
    else
      v_nro_documento := p_nro_documento;
    end if;

    if nvl(v_nro_documento, '0') != '0' then
      begin
        select l.apodo
          into v_apodo
          from tm_per_lis_blancas l
         where l.nro_documento = v_nro_documento
           and rownum = 1;
      exception
        when no_data_found then
          begin
            select p.pri_nombre
              into v_apodo
              from ba_per_fisicas p
             where p.cod_persona = p_cod_persona
               and rownum = 1;
          exception
            when no_data_found then
              p_cod_error := 1;
              p_mensaje   := 'No se existe la persona: ' || p_cod_persona;
            when others then
              p_cod_error := 2;
              p_mensaje   := 'No se pudo optener datos de la persona  ' ||
                             p_cod_persona;
          end;
      end;
    end if;

    if nvl(p_cod_error, 0) = 0 then
      begin
        insert into it.ba_onb_correos
          (cod_persona, apodo, tip_producto, estado, fec_registro)
        values
          (p_cod_persona, v_apodo, p_tip_producto, 'P', sysdate);
        p_cod_error := 0;
      exception
        when others then
          p_cod_error := 99;
          p_mensaje   := substr('Error al insertar correo onb: ' || sqlerrm,
                                1,
                                4000);
      end;
    else
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ENV_NOT_ONBOARDING',
                              substr(p_mensaje, 1, 4000),
                              p_cod_persona,
                              null);
      end if;
    end if;
  exception
    when others then
      p_cod_error := 99;
      p_mensaje   := substr('Error en el proceso de carga correo onb: ' ||
                            sqlerrm,
                            1,
                            4000);
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ENV_NOT_ONBOARDING',
                              substr('Documento Nro. ' || p_nro_documento ||
                                     ' Error: ' || p_mensaje,
                                     1,
                                     4000),
                              p_cod_persona,
                              null);
      end if;
  end pr_env_not_onboarding;
  --DA-4820
  procedure pr_act_dat_persona(p_cod_persona      in ba_personas.cod_persona%type,
                               p_profesion        in ba_personas.cod_rub_primario%type,
                               p_direccion        in ba_direcciones.direccion%type,
                               p_cod_pais         in ba_direcciones.cod_pais%type,
                               p_cod_ciudad       in ba_direcciones.cod_ciudad%type,
                               p_nro_casa         IN ba_direcciones.numero%TYPE,
                               p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                               p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                               p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                               p_piso             IN ba_direcciones.piso%TYPE,
                               p_edificio         IN ba_direcciones.edificio%TYPE,
                               p_referencias      IN ba_direcciones.observacion%TYPE,
                               p_telefono         in VARCHAR2,
                               p_correo           in ba_personas.dir_correo%type,
                               p_latitud          in ba_direcciones.latitud%TYPE,
                               p_longitud         in ba_direcciones.longitud%TYPE,
                               p_cod_error        out number,
                               p_mensaje          out varchar2) is
    v_existe   varchar2(1);
    v_retorno  varchar2(4000);
    v_cod_pais ba_direcciones.cod_pais%type;
    v_cantidad number := 0;
    v_existe_per varchar2(1);
    v_existe_dir varchar2(1);
  begin
    if p_profesion is null then
      p_cod_error := 3;
      p_mensaje   := 'El rubro primario no puede ser null';
    end if;
    if p_direccion is null then
      p_cod_error := 3;
      p_mensaje   := 'La direccion no puede ser null';
    end if;
    if p_cod_pais is null then
      v_cod_pais := fu_obt_cod_pais(p_cod_departamento, p_cod_ciudad);
      if v_cod_pais is null then
        p_cod_error := 3;
        p_mensaje   := 'El codigo de pais no puede ser null';
      end if;
    end if;
    if p_cod_ciudad is null then
      p_cod_error := 3;
      p_mensaje   := 'El codigo de ciudad no puede ser null';
    end if;

    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if p_profesion is not null and p_correo is not null then
      --Se actualiza rubro / correo
      update ba_personas p
         set p.dir_correo = p_correo, p.cod_rub_primario = p_profesion
       where p.cod_persona = p_cod_persona;
    end if;
    if p_telefono is not null then
      v_existe  := null;
      v_retorno := null;
      begin
         select 'S'
          into v_existe
          from ba_telefonos t
         where (t.telefono = p_telefono or
               t.area || t.telefono = p_telefono or
              t.telefono = replace(p_telefono,'+595','0'))
           and t.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          v_existe := 'S';
        when others then
          p_cod_error := 3;
          p_mensaje   := substr('Error al recuperar telefonos de la persona ' ||
                                p_cod_persona || ' Telefono ' || p_telefono ||
                                ' - ' || sqlerrm,
                                1,
                                4000);
      end;

      savepoint telefono;
      --se deja todos los nros como no principal
      update ba_telefonos
         set principal = 'N'
       where cod_persona = p_cod_persona
         and principal = 'S';
      if nvl(v_existe, 'N') = 'S' then
        ---buscamos registro de Tipo P = Personal
         begin
           select 'S'
            into v_existe_per
            from ba_telefonos t
           where (t.telefono = p_telefono or
                 t.area || t.telefono = p_telefono or
                t.telefono = replace(p_telefono,'+595','0'))
             and t.cod_persona = p_cod_persona
             and t.tipo='P';
        exception
          when no_data_found then
            v_existe_per := 'N';
          when too_many_rows then
            v_existe_per := 'S';
         end;

        if v_existe_per='S' then
        -- actualiza el registro Tipo Personal como principal
          update ba_telefonos
             set principal = 'S', tipo = 'P'
           where (telefono = p_telefono or area || telefono = p_telefono or
                 telefono = replace(p_telefono,'+595','0'))
             and cod_persona = p_cod_persona
             and tipo='P'
             and rownum = 1;
        else
          -- actualiza el registro que retorna como principal
          update ba_telefonos
           set principal = 'S', tipo = 'P'
         where (telefono = p_telefono or area || telefono = p_telefono or
               telefono = replace(p_telefono,'+595','0'))
           and cod_persona = p_cod_persona
           and rownum = 1;
        end if;

        if sql%rowcount = 0 then
          p_cod_error := 99;
          p_mensaje   := 'No se pudo actualizar el telefono ' || p_telefono ||
                         ' como principal';
          rollback to telefono;
        else
          begin
            select count(*)
              into v_cantidad
              from ba_telefonos
             where cod_persona = p_cod_persona
               and principal = 'S';
            if v_cantidad > 1 then
              rollback to telefono;
            end if;
          exception
            when others then
              null;
          end;
        end if;
      else
        --Si no existe inserta el nuevo nro de telefono como principal
        v_retorno := fu_ins_tel_persona(p_cod_persona, p_telefono);
        if nvl(v_retorno, 'X') != 'S' then
          p_cod_error := 99;
          p_mensaje   := v_retorno;
          rollback to telefono;
        end if;
      end if;
    end if;
    if p_direccion is not null and v_cod_pais is not null and
       p_cod_ciudad is not null then
      v_existe  := null;
      v_retorno := null;
      begin
        select 'S'
          into v_existe
          from ba_direcciones t
         where t.direccion = p_direccion
           and t.cod_pais = nvl(p_cod_pais,v_cod_pais)
           and t.cod_ciudad = p_cod_ciudad
           and t.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          v_existe := 'S';
        when others then
          p_cod_error := 3;
          p_mensaje   := substr('Error al recuperar direcciones de la persona ' ||
                                p_cod_persona || ' Direccion: ' ||
                                p_direccion || ' Pais: ' || p_cod_pais ||
                                ' Ciudad: ' || p_cod_ciudad || ' - ' ||
                                sqlerrm,
                                1,
                                4000);
      end;

      savepoint direccion;
      v_cantidad := 0;
      --se deja todos los nros como no principal
      update ba_direcciones
         set principal = 'N'
       where cod_persona = p_cod_persona
         and principal = 'S';
      if nvl(v_existe, 'N') = 'S' then
        ---buscamos registro de Tipo P = Personal
         begin
           select 'S'
          into v_existe_dir
          from ba_direcciones t
         where t.direccion = p_direccion
           and t.cod_pais = nvl(p_cod_pais,v_cod_pais)
           and t.cod_ciudad = p_cod_ciudad
           and t.cod_persona = p_cod_persona
           and t.tipo='P';
        exception
          when no_data_found then
            v_existe_dir := 'N';
          when too_many_rows then
            v_existe_dir := 'S';
         end;

      if v_existe_dir='S' then
       -- actualiza el registro Tipo Personal como principal
       update ba_direcciones d
         set principal = 'S', tipo = 'P'
       where direccion = p_direccion
         and cod_pais = nvl(p_cod_pais,v_cod_pais)
         and cod_ciudad = p_cod_ciudad
         and cod_persona = p_cod_persona
         and tipo='P'
         and rownum = 1;
      else
        --se actualiza la direccion como principal
        update ba_direcciones d
           set principal = 'S', tipo = 'P'
         where direccion = p_direccion
           and cod_pais = nvl(p_cod_pais,v_cod_pais)
           and cod_ciudad = p_cod_ciudad
           and cod_persona = p_cod_persona
           and rownum = 1;
       end if;
        if sql%rowcount = 0 then
          p_cod_error := 99;
          p_mensaje   := 'No se pudo actualizar la direccion ' ||
                         p_direccion || ' como principal';
          rollback to direccion;
        else
          begin
            select count(*)
              into v_cantidad
              from ba_direcciones
             where cod_persona = p_cod_persona
               and principal = 'S';
            if v_cantidad > 1 then
              rollback to direccion;
            end if;
          exception
            when others then
              null;
          end;
        end if;
      else
        --Si no existe inserta la nueva direccion como principal
        v_retorno := fu_ins_dir_persona(p_cod_persona,
                                        p_cod_pais,
                                        p_cod_ciudad,
                                        p_direccion,
                                        p_nro_casa,
                                        p_cal_secundaria,
                                        p_cod_barrio,
                                        p_cod_departamento,
                                        p_piso,
                                        p_edificio,
                                        p_referencias,
                                        p_latitud,
                                        p_longitud);
        if nvl(v_retorno, 'X') != 'S' then
          p_cod_error := 99;
          p_mensaje   := v_retorno;
          rollback to direccion;
        end if;
      end if; --direccion
    end if;
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
       nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PAG_PLA.PR_ACT_DAT_PERSONA',
                            substr('Error en la actualizacion de datos: ' ||
                                   p_mensaje,
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;
  exception
    when others then
      p_mensaje   := substr(DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace ||
                            ' Cod.Persona: ' || p_cod_persona ||
                            ' Direccion: ' || p_direccion || ' Pais: ' ||
                            p_cod_pais || ' Ciudad: ' || p_cod_ciudad ||
                            'Correo: ' || p_correo || ' Telefono: ' ||
                            p_telefono || ' Profesion: ' || p_profesion,
                            1,
                            4000);
      p_cod_error := 4;
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
         nvl(p_cod_error, 0) != 0 then
        prg_ins_log_programas('PAG_PLA.PR_ACT_DAT_PERSONA',
                              substr(p_mensaje, 1, 4000),
                              p_cod_persona,
                              null);
      end if;
  end pr_act_dat_persona;

  PROCEDURE pr_alt_per_jur_onb(p_nombre              in ba_personas.nom_completo%type,
                               p_nro_documento       in ba_personas.nro_documento%type,
                               p_tip_documento       in ba_personas.cod_tip_documento%type,
                               p_naturaleza          in ba_per_juridicas.naturaleza%type,
                               p_cod_pais            in ba_ciudades.cod_pais%type,
                               p_dir_correo          in ba_personas.dir_correo%type,
                               p_rub_primario        in ba_personas.cod_rub_primario%type,
                               p_cod_ciudad          in ba_ciudades.cod_ciudad%type,
                               p_direccion           in ba_direcciones.direccion%type,
                               p_fon_transferencia   in cr_inf_fondos.fon_transferencias%type,
                               p_fon_salario         in cr_inf_fondos.fon_salario%type,
                               p_fon_prestamo        in cr_inf_fondos.fon_prestamos%type,
                               p_fon_vta_activos     in cr_inf_fondos.fon_vta_activos%type,
                               p_fon_ren_financieras in cr_inf_fondos.fon_ren_financieras%type,
                               p_fon_herencia        in cr_inf_fondos.fon_herencia%type,
                               p_fon_ahorro          in cr_inf_fondos.fon_ahorro%type,
                               p_fon_otros           in cr_inf_fondos.fon_otros%type,
                               p_tiene_doc           in varchar2,
                               p_cod_persona         out ba_personas.cod_persona%type,
                               p_cod_error           out number,
                               p_mensaje             out varchar2,
                               p_nro_documento_soli  in ba_personas.nro_documento%type,
                               p_cod_onboarding      in varchar2,
                               p_tip_cliente         out ba_onb_empresas.tip_cliente%type) IS

    v_log_mensaje  varchar2(4000);
    v_rub_primario ge_rub_economicos.cod_rub_economico%type;
    v_nombre       varchar2(200);
    r_bpers        ba_personas%ROWTYPE;
    r_bperj        ba_per_juridicas%ROWTYPE;
    v_cod_persona  ba_personas.cod_persona%type;
    v_retorno      varchar2(4000) := null;
    v_existe_dir   varchar2(1);
    v_existe_inf   varchar2(1);
    v_exi_mail     varchar2(1);
    v_principal    ba_direcciones.principal%type;
    v_cod_per_soli ba_personas.cod_persona%type;
    v_val_adicional ge_par_dinamicos.val_parametro%type;
    v_tip_cliente  ba_onb_empresas.tip_cliente%type;
    v_naturaleza   ba_per_juridicas.naturaleza%type;

  BEGIN
    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;

    if p_nombre is null then
      p_mensaje   := 'El Nombre no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_nro_documento is null then
      p_mensaje   := 'El Nro. de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_tip_documento is null then
      p_mensaje   := 'Tipo de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_naturaleza is null then
      p_mensaje   := 'La Naturaleza no puede ser nula.';
      p_cod_error := 3;
      return;
    else
      v_naturaleza := fug_obt_tip_emp_onb(p_naturaleza);
    end if;

    if p_cod_pais is null then
      p_mensaje   := 'El Codigo de Pais no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_dir_correo is null then
      p_mensaje   := 'El Correo no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_rub_primario is null then
      p_mensaje   := 'El Rubro Primario no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_cod_ciudad is null then
      p_mensaje   := 'El codigo de Ciudad no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_direccion is null then
      p_mensaje   := 'La Direccion no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_transferencia is null then
      p_mensaje   := 'Fondo de Transferencia no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_salario is null then
      p_mensaje   := 'Fondo de Salario no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_prestamo is null then
      p_mensaje   := 'Fondo de Prestamo no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_vta_activos is null then
      p_mensaje   := 'Fondo Venta de Activos no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_ren_financieras is null then
      p_mensaje   := 'Fondo Renta Financieras no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_herencia is null then
      p_mensaje   := 'Fondo Herencia no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_ahorro is null then
      p_mensaje   := 'Fondo de Ahorro no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_fon_otros is null then
      p_mensaje   := 'Otros Fondos no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;
    --DA-9235
    if p_nro_documento_soli is null then
      p_mensaje   := 'El Nro. de documento del solicitante no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_rub_primario is not null and nvl(p_cod_error, 0) = 0 then
      BEGIN
        SELECT cod_rub_economico
          INTO v_rub_primario
          FROM ge_rub_economicos e
         WHERE cod_rub_economico =
               (select val_maximo
                  from ba_cod_referencias T
                 where t.dominio = 'ONB_EMP_OCUPACIONES'
                   and t.val_minimo = p_rub_primario);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          p_mensaje   := 'No existe Actividad Economica ' || p_rub_primario;
          p_cod_error := 4;
        WHEN OTHERS THEN
          p_cod_error   := 4;
          p_mensaje     := 'Error al verificar Actividad Economica ' || p_rub_primario;
          v_log_mensaje := substr('Error al verificar rubro primario ' || p_rub_primario || ' ' ||
                           DBMS_UTILITY.format_error_stack || ' - ' ||
                           DBMS_UTILITY.format_error_backtrace, 1, 4000);
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                 v_log_mensaje,
                                 null,
                                 null);

      END;
    end if;

    v_nombre                  := upper(TRIM(p_nombre));
    r_bpers.tipo              := 'J';
    r_bpers.nro_documento     := upper(TRIM(p_nro_documento));
    r_bpers.cod_tip_documento := p_tip_documento;
    r_bpers.cod_rub_primario  := v_rub_primario;
    r_bpers.cod_actividad     := fug_obt_cod_actividad(v_rub_primario);
    r_bpers.cod_pais          := nvl(p_cod_pais, 1);
    r_bpers.cod_ciu_origen    := nvl(p_cod_ciudad, 1);
    r_bpers.dir_correo        := p_dir_correo;
    r_bperj.raz_social        := TRIM(upper(substr(p_nombre, 1, 120)));
    r_bperj.nom_comercial     := TRIM(upper(substr(p_nombre, 1, 65)));
    r_bperj.naturaleza        := TRIM(v_naturaleza);

    BEGIN
      SELECT cod_persona, 'E'
        INTO v_cod_persona, v_tip_cliente
        FROM ba_personas
       WHERE cod_tip_documento = cod_tip_documento
         AND nro_documento = p_nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
        v_cod_persona := null;
        v_tip_cliente := 'N';
    END;
    IF nvl(v_cod_persona, 'N') = 'N' and nvl(p_cod_error, 0) = 0 THEN
      BEGIN
        --- No existe la persona
        SELECT s_cod_persona.nextval INTO v_cod_persona FROM dual;

        INSERT INTO ba_personas
          (cod_persona,
           nom_completo,
           tipo,
           cod_tip_documento,
           nro_documento,
           cod_pais,
           cod_ciu_origen,
           cod_rub_primario,
           dir_correo,
           cod_actividad)
        VALUES
          (v_cod_persona,
           v_nombre,
           r_bpers.tipo,
           r_bpers.cod_tip_documento,
           r_bpers.nro_documento,
           r_bpers.cod_pais,
           r_bpers.cod_ciu_origen,
           r_bpers.cod_rub_primario,
           r_bpers.dir_correo,
           r_bpers.cod_actividad);

      EXCEPTION
        WHEN OTHERS THEN
          p_mensaje     := 'Ocurrio un error al crear Persona ';
          v_log_mensaje := substr('Ocurrio un error al crear Persona ' ||
                                  SQLERRM || ' Nombre: ' || v_nombre ||
                                  ' Tipo: ' || r_bpers.tipo ||
                                  ' Tipo Doc: ' ||
                                  r_bpers.cod_tip_documento || ' Pais: ' ||
                                  r_bpers.cod_pais || ' Rub.Primario: ' ||
                                  r_bpers.cod_rub_primario || ' Correo: ' ||
                                  r_bpers.dir_correo || ' Actividad: ' ||
                                  r_bpers.cod_actividad, 1, 4000);
          p_cod_error   := 99;
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                  v_log_mensaje,
                                  v_cod_persona,
                                  null);
      END;

      if nvl(p_cod_error, 0) = 0 then
        v_retorno := fu_ins_ba_per_juridicas(v_cod_persona, r_bperj); --OJO HAY QUE PASAR!!!!!!!
        if nvl(v_retorno, 'N') != 'S' then
          p_mensaje     := 'Ocurrio un error al crear persona Juridica';
          v_log_mensaje := nvl(v_retorno, p_mensaje);
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                 v_log_mensaje,
                                 v_cod_persona,
                                 null);
          p_cod_error := 99;
        end if;
      end if;

      if nvl(p_cod_error, 0) = 0 then
        BEGIN
          SELECT 'S'
            INTO v_existe_dir
            FROM ba_direcciones
           WHERE cod_persona = v_cod_persona;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_direcciones
                (cod_persona,
                 cod_direccion,
                 cod_ciudad,
                 direccion,
                 tipo,
                 principal,
                 cod_pais)
              VALUES
                (v_cod_persona,
                 1,
                 p_cod_ciudad,
                 p_direccion,
                 'L',
                 'S',
                 p_cod_pais);
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje     := 'Error al insertar la Direccion';
                v_log_mensaje := substr('Error al insertar en ba_direcciones. ' ||
                                 DBMS_UTILITY.format_error_stack ||
                                 ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000);
                p_cod_error   := 99;
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                 v_log_mensaje,
                                 v_cod_persona,
                                 null);
            END;
        END;
      end if;
      if nvl(p_cod_error, 0) != 0 then
        p_mensaje   := 'Ocurrió un error al crear la Empresa';
        p_cod_error := 99;
      end if;
      -- DA-9624
      if p_cod_onboarding is not null then
        update ba_onb_empresas t
           set t.tip_cliente = decode(v_tip_cliente,
                                      'N',
                                      'NUEVO',
                                      'E',
                                      'EXISTENTE')
         where t.cod_onb_emp = p_cod_onboarding;
      end if;
    else
      if v_cod_persona is not null then
        /*update ba_personas t
           sett.dir_correo       = p_dir_correo,
               t.cod_rub_primario = v_rub_primario,
               t.cod_actividad    = r_bpers.cod_actividad,
               t.cod_ciu_origen   = p_cod_ciudad
         where t.cod_persona = v_cod_persona;*/
         -- DA-9624
          update ba_onb_empresas t
             set t.tip_cliente = decode(v_tip_cliente,
                                        'N',
                                        'NUEVO',
                                        'E',
                                        'EXISTENTE')
           where t.cod_onb_emp = p_cod_onboarding;
      end if;
      p_tip_cliente := v_tip_cliente;
      /*if nvl(p_cod_error, 0) = 0 then
        BEGIN
          SELECT 'S', principal
            INTO v_existe_dir, v_principal
            FROM ba_direcciones
           WHERE cod_persona = v_cod_persona
             and principal = 'S';
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_direcciones
                (cod_persona,
                 cod_ciudad,
                 direccion,
                 tipo,
                 principal,
                 cod_pais)
              VALUES
                (v_cod_persona,
                 p_cod_ciudad,
                 p_direccion,
                 'L',
                 case when nvl(v_principal, 'N') = 'S' then 'N' else 'S' end,
                 p_cod_pais);
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje     := 'Error al insertar la Direccion';
                v_log_mensaje := substr('Error al insertar en ba_direcciones. ' ||
                                 DBMS_UTILITY.format_error_stack ||
                                 ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000);
                p_cod_error   := 99;
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                 v_log_mensaje,
                                 v_cod_persona,
                                 null);
            END;
        END;
        if nvl(v_existe_dir, 'N') = 'S' then
          BEGIN
            INSERT INTO ba_direcciones
              (cod_persona,
               cod_ciudad,
               direccion,
               tipo,
               principal,
               cod_pais)
            VALUES
              (v_cod_persona,
               p_cod_ciudad,
               p_direccion,
               'L',
               case when nvl(v_principal, 'N') = 'S' then 'N' else 'S' end,
               p_cod_pais);
          EXCEPTION
            WHEN OTHERS THEN
              p_mensaje     := 'Error al insertar la Direccion';
              v_log_mensaje := substr('Error al insertar en ba_direcciones. ' ||
                               DBMS_UTILITY.format_error_stack ||
                               ' - ' ||
                               DBMS_UTILITY.format_error_backtrace,
                               1,
                               4000);
              p_cod_error   := 99;
              prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                     v_log_mensaje,
                                     v_cod_persona,
                                     null);
          END;
        end if;
      end if;*/
     /* if nvl(p_cod_error, 0) = 0 then
        BEGIN
          select 'S'
            into v_existe_inf
            from cr_inf_fondos t
           where t.cod_persona = v_cod_persona;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              insert into cr_inf_fondos
                (COD_PERSONA,
                 FON_TRANSFERENCIAS,
                 FON_SALARIO,
                 FON_PRESTAMOS,
                 FON_VTA_ACTIVOS,
                 FON_REN_FINANCIERAS,
                 FON_HERENCIA,
                 FON_AHORRO,
                 FON_OTROS,
                 TIP_OPE_OTROS,
                 PEP,
                 PEP_OBSERVACION
                 ONG)
              values
                (v_cod_persona,
                 p_fon_transferencia,
                 p_fon_salario,
                 p_fon_prestamo,
                 p_fon_vta_activos,
                 p_fon_ren_financieras,
                 p_fon_herencia,
                 p_fon_ahorro,
                 p_fon_otros,
                 'N',
                 'N',
                 null
                 'N');
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje     := 'Error al insertar la Direccion';
                v_log_mensaje := substr('Error al insertar en ba_direcciones. ' ||
                                 DBMS_UTILITY.format_error_stack ||
                                 ' - ' ||
                                 DBMS_UTILITY.format_error_backtrace,
                                 1,
                                 4000);
                p_cod_error   := 99;
                prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                       v_log_mensaje,
                                       v_cod_persona,
                                       null);
            END;

          WHEN others then
            p_mensaje     := 'Ocurrio un error al Insertar Inf. Fondos ';
            v_log_mensaje := substr('Ocurrio un error al Insertar Inf. Fondos. ' ||
                             DBMS_UTILITY.format_error_stack ||
                             ' - ' ||
                             DBMS_UTILITY.format_error_backtrace,
                             1,
                             4000);
            p_cod_error   := 4;
        end;
        if nvl(v_existe_inf, 'N') = 'S' and nvl(p_cod_error, 0) = 0 then
          update cr_inf_fondos t
             set t.fon_transferencias  = p_fon_transferencia,
                 t.fon_salario         = p_fon_salario,
                 t.fon_prestamos       = p_fon_prestamo,
                 t.fon_vta_activos     = p_fon_vta_activos,
                 t.fon_ren_financieras = p_fon_ren_financieras,
                 t.fon_herencia        = p_fon_herencia,
                 t.fon_ahorro          = p_fon_ahorro,
                 t.fon_otros           = p_fon_otros
           where t.cod_persona = v_cod_persona;
        end if;
      end if;*/
    END IF;
   if nvl(p_cod_error, 0) = 0  then
      -- valida si existe el parametro para esa persona
        begin
          select 'S'
            into v_exi_mail
            from ba_per_dat_adicionales
           where parametro = 'EMAIL_ONB_EMPRESAS'
           and cod_persona = v_cod_persona;
        exception
          when no_data_found then
            v_exi_mail := 'N';
        end;
        if nvl(v_exi_mail,'N') = 'N' then
          begin
            insert into ba_per_dat_adicionales
              (cod_persona, parametro, val_parametro)
            values
              (v_cod_persona, 'EMAIL_ONB_EMPRESAS', p_dir_correo);
          exception
            when others then
              p_mensaje     := 'Error al insertar datos adicionales';
              v_log_mensaje := substr('Error al insertar datos adicionales. ' ||
                                      DBMS_UTILITY.format_error_stack ||
                                      ' - ' ||
                                      DBMS_UTILITY.format_error_backtrace,
                                      1,
                                      4000);
              p_cod_error   := 99;
              prg_ins_log_programas('pag_pla.PR_ALT_PER_JUR_ONB',
                                    v_log_mensaje,
                                    v_cod_persona,
                                    null);
          end;
        end if;
    end if;
    --DA-9235
    if nvl(p_cod_error, 0) = 0 then
        begin
          select cod_persona
            into v_cod_per_soli
            from ba_personas
           where cod_tip_documento = 1
             and nro_documento = p_nro_documento_soli;
        exception
          when no_data_found then
            v_cod_per_soli := null;
        end;
        --Busco si esta relacionado los parametros
      if v_cod_per_soli is not null then
              if nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'), 'N') = 'S' AND
                nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'MAX_REG_SOL_ONB_EMPRESA'), 'N') = 'S' THEN
                -- Actualiza
                begin
                  update ba_per_dat_adicionales
                     set val_parametro = val_parametro + 1
                   where parametro = 'CAN_REG_ONB_EMPRESA'
                     and cod_persona = v_cod_per_soli;
                end;
              end if;
              --Verifico si posee relacion parametrica
              if nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'), 'N') = 'N' AND
                nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'MAX_REG_SOL_ONB_EMPRESA'), 'N') = 'N' THEN
                --busco el valor del parametro adicional
                 begin
                   select fug_obt_pardinamico('ONB_MAX_REG_EMPRESA')
                     into v_val_adicional
                     from dual;
                 end;
                if v_val_adicional is not null then
                    begin
                        insert into ba_per_dat_adicionales
                          (cod_persona, parametro, val_parametro)
                        values
                          (v_cod_per_soli,'MAX_REG_SOL_ONB_EMPRESA',v_val_adicional);
                      exception
                        when others then
                          p_mensaje     := 'Error al insertar datos adicionales';
                          v_log_mensaje := substr('Error al insertar datos adicionales. ' ||
                                                  DBMS_UTILITY.format_error_stack ||' - ' ||
                                                  DBMS_UTILITY.format_error_backtrace,1,4000);
                          p_cod_error   := 99;
                          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',v_log_mensaje,v_cod_persona,null);
                    end;
                    begin
                        insert into ba_per_dat_adicionales
                          (cod_persona, parametro, val_parametro)
                        values
                          (v_cod_per_soli,'CAN_REG_ONB_EMPRESA','1');
                      exception
                        when others then
                          p_mensaje     := 'Error al insertar datos adicionales';
                          v_log_mensaje := substr('Error al insertar datos adicionales. ' ||
                                                  DBMS_UTILITY.format_error_stack ||' - ' ||
                                                  DBMS_UTILITY.format_error_backtrace,1,4000);
                          p_cod_error   := 99;
                          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',v_log_mensaje,v_cod_persona,null);
                    end;
                  end if;
              end if;
       end if;
     end if;
    --DA-9193
    if nvl(v_naturaleza, 0) = fug_obt_pardinamico('VAL_MIN_EMP_UNI') then --and nvl(p_tiene_doc, 'N') = 'N' then
       /*if paw_cir.fu_ini_circuito(923, v_cod_persona, v_cod_persona) <> 0 then
          v_log_mensaje := substr('Error al iniciar el Circuito de Documentos Pendientes Empresas ' ||
                           paw_cir.G_MSJ_ERROR, 1, 4000);
          prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                           substr('Error: ' || v_log_mensaje, 1, 4000), v_cod_persona, null);
       end if;*/
     begin
         update ba_onb_empresas s
            set s.adj_documento = nvl(p_tiene_doc, 'N')
          where s.cod_onb_emp = p_cod_onboarding;
         if sql%notfound then
           v_log_mensaje := 'Ningun registro procesado para el codigo onboarding ' ||p_cod_onboarding;
           it.prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                    v_log_mensaje,
                                    null,
                                    null);
         end if;
       exception
         when others then
           v_log_mensaje := 'Ningun registro procesado para el codigo onboarding ' ||p_cod_onboarding;
           it.prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                                    v_log_mensaje,
                                    null,
                                    null);
       end;

    end if;

    if nvl(p_cod_error, 0) = 0 then
      p_cod_persona := v_cod_persona;
      p_mensaje     := null;
      p_cod_error   := 0;
      p_tip_cliente := v_tip_cliente;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      v_log_mensaje := substr('Error al procesar el alta de la persona Juridica' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace, 1, 4000);
      p_cod_error   := 99;
      p_mensaje     := 'Ocurrio un error inesperado durante el proceso del alta de persona';
      prg_ins_log_programas('PAG_PLA.PR_ALT_PER_JUR_ONB',
                              substr('Error: ' || v_log_mensaje, 1, 4000), v_cod_persona, null);

      rollback;
  END;

   PROCEDURE  pr_alt_vin_fir_per_onb( p_nombres        in ba_personas.nom_completo%type,
                                     p_apellidos      in ba_personas.nom_completo%type,
                                     p_nro_documento  in ba_personas.nro_documento%type,
                                     p_tip_documento  in ba_personas.cod_tip_documento%type,
                                     p_cod_pais       in ba_personas.cod_pais%type,
                                     p_dir_correo     in ba_personas.dir_correo%type,
                                     p_rub_primario   in ba_personas.cod_rub_primario%type,
                                     p_num_celular    in varchar2,
                                     p_fec_nacimiento in ba_per_fisicas.fec_nacimiento%type,
                                     p_cod_sexo       in ba_per_fisicas.cod_sexo%type,
                                     p_tip_guardado   in varchar2, --F=(FIRMANTE) U=(USUARIO)
                                     p_fatca          in varchar2,
                                     p_cod_persona    out ba_personas.cod_persona%type,
                                     p_cod_error      out number,
                                     p_mensaje        out varchar2) IS
   v_exi_persona      varchar2(1);
   v_val_rub_primario ba_cod_referencias.val_minimo%type;
   v_ins_telefono     varchar2(30);
   v_cod_persona      ba_personas.cod_persona%type;
   v_exi_fatca        varchar(1) := 'N';
  BEGIN
    BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;

    p_cod_error := 0;
    p_mensaje   := nvl(fug_obt_pardinamico('DES_MSG_EXITO'), 'Transaccion Exitosa!');

    IF p_nombres IS NULL THEN
       p_cod_error := 1;
       p_mensaje   := 'Nombre no puede ser nulo';
       RETURN;
    END IF;

    IF p_apellidos IS NULL THEN
       p_cod_error := 2;
       p_mensaje   := 'Apellido no puede ser nulo';
       RETURN;
    END IF;

    IF p_nro_documento IS NULL THEN
       p_cod_error := 3;
       p_mensaje   := 'Nro de documento no puede ser nulo';
       RETURN;
    END IF;

    IF p_tip_documento IS NULL THEN
       p_cod_error := 4;
       p_mensaje   := 'El tipo de documento no puede ser nulo';
       RETURN;
    END IF;

    IF p_cod_pais IS NULL THEN
       p_cod_error := 5;
       p_mensaje   := 'El pais no puede ser nulo';
       RETURN;
    END IF;

    IF p_dir_correo IS NULL THEN
       p_cod_error := 6;
       p_mensaje   := 'La direccion de correo no puede ser nulo';
       RETURN;
    END IF;

    IF p_rub_primario IS NULL THEN
       p_cod_error := 7;
       p_mensaje   := 'El rubro primario no puede ser nulo';
       RETURN;
    END IF;

    /*IF p_fec_nacimiento IS NULL THEN
       p_cod_error := 8;
       p_mensaje   := 'La fecha de nacimiento no puede ser nulo';
       RETURN;
    END IF;*/

    IF p_num_celular IS NULL THEN
       p_cod_error := 9;
       p_mensaje   := 'El numero de celular no puede ser nulo';
       RETURN;
    END IF;

    /*IF p_cod_sexo IS NULL THEN
       p_cod_error := 10;
       p_mensaje   := 'El codigo de sexo no puede ser nulo';
       RETURN;
    END IF;*/

    IF p_tip_guardado IS NULL THEN
       p_cod_error := 11;
       p_mensaje   := 'Tipo guardado no puede ser nulo';
       RETURN;
    ELSIF p_tip_guardado NOT IN ('F','U') THEN
       p_cod_error := 12;
       p_mensaje   := 'Tipo guardado incorrecto, los valores esperados son F o U ';
       RETURN;
    END IF;

    IF p_fatca IS NULL THEN
       IF nvl(p_tip_guardado,'X')  = 'F' then
          p_cod_error := 13;
          p_mensaje   := 'Fatca no puede ser nulo';
          RETURN;
       END IF;
    END IF;

    BEGIN
      SELECT t.val_maximo
        INTO v_val_rub_primario
        FROM ba_cod_referencias t
       WHERE t.dominio    = 'ONB_EMP_OCUPACIONES'
         AND t.val_minimo = p_rub_primario;
    EXCEPTION
       WHEN no_data_found THEN
          p_cod_error := 14;
          p_mensaje   := 'No existe la actividad economica '||p_rub_primario;
          RETURN;
       WHEN OTHERS THEN
          p_cod_error := 15;
          p_mensaje   := 'Error al obtener rubro primario '||sqlerrm;
          RETURN;
    END;

    BEGIN
      SELECT p.cod_persona
        INTO v_cod_persona
        FROM ba_personas p
       WHERE p.cod_tip_documento = p_tip_documento
         AND p.nro_documento     = p_nro_documento;
    EXCEPTION
       WHEN no_data_found THEN
          v_cod_persona := NULL;
       WHEN OTHERS THEN
          v_cod_persona := NULL;
    END;

    IF v_cod_persona IS NULL THEN
        SELECT s_cod_persona.nextval INTO v_cod_persona FROM dual;
        BEGIN
          INSERT INTO ba_personas
            (cod_persona,
             nom_completo,
             tipo,
             cod_tip_documento,
             nro_documento,
             cod_pais,
             cod_rub_primario,
             cod_actividad,
             dir_correo
             )
          VALUES
            (v_cod_persona,
             substr(upper(p_nombres)||' '||upper(p_apellidos),1,120),
             'F',
             p_tip_documento,
             p_nro_documento,
             p_cod_pais,
             v_val_rub_primario,
             fug_obt_cod_actividad(v_val_rub_primario),
             p_dir_correo
             );
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error := 14;
              p_mensaje   := 'Ocurrio un error al insertar la persona '||sqlerrm;
              RETURN;
          END;

       IF p_cod_error = 0 THEN
          BEGIN
            INSERT INTO ba_per_fisicas
              (cod_persona,
               pri_nombre,
               seg_nombre,
               pri_apellido,
               seg_apellido,
               cod_sexo,
               fec_nacimiento
               )
            VALUES
              (v_cod_persona,
               upper(fug_obt_nombre(p_nombres, 1)),
               upper(fug_obt_nombre(p_nombres, 2)),
               upper(fug_obt_nombre(p_apellidos, 1)),
               upper(fug_obt_nombre(p_apellidos, 2)),
               nvl(p_cod_sexo,'M'),
               p_fec_nacimiento
             );
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error := 15;
              p_mensaje   := 'Ocurrio un error al insertar la persona fisica '||sqlerrm;
              RETURN;
          END;
        END IF;



        IF p_cod_error = 0 THEN

            v_ins_telefono := fu_ins_tel_persona( v_cod_persona, p_num_celular );

            IF p_tip_guardado = 'F' THEN

               BEGIN
                  INSERT INTO ba_per_dat_adicionales
                    (cod_persona, parametro, val_parametro)
                  VALUES
                    (v_cod_persona, 'PER_IND_FATCA', p_fatca);
                EXCEPTION
                  WHEN OTHERS THEN
                    p_mensaje     := 'Error al insertar parametro adicional de la persona';
                    p_cod_error   := 16;
                END;

            END IF;

        END IF;

    ELSE
      --HA-3544
        /*  UPDATE ba_personas p
             SET p.dir_correo       = p_dir_correo
               --  p.cod_rub_primario = v_val_rub_primario,
               --  p.cod_actividad    = fug_obt_cod_actividad(v_val_rub_primario)
           WHERE p.cod_persona      = v_cod_persona;*/

          /* UPDATE ba_per_fisicas t
              SET t.pri_nombre   = upper(fug_obt_nombre(p_nombres, 1)),
                  t.seg_nombre   = upper(fug_obt_nombre(p_nombres, 2)),
                  t.pri_apellido = upper(fug_obt_nombre(p_apellidos, 1)),
                  t.seg_apellido = upper(fug_obt_nombre(p_apellidos, 2))
                  t.fec_nacimiento = p_fec_nacimiento
            WHERE t.cod_persona  = v_cod_persona;*/

         IF p_tip_guardado = 'F' THEN
            begin
              select 'S'
                into v_exi_fatca
                from ba_per_dat_adicionales p
               where p.cod_persona = v_cod_persona
                 and p.parametro = 'PER_IND_FATCA';
            exception
              when no_data_found then
                v_exi_fatca := 'N';
              when others then
                v_exi_fatca := 'N';
            end;
             /*UPDATE ba_per_dat_adicionales a
                SET a.val_parametro = p_fatca
              WHERE a.cod_persona   = v_cod_persona
                AND a.parametro     = 'PER_IND_FATCA';*/
              IF v_exi_fatca = 'N' THEN
                 BEGIN
                   INSERT INTO ba_per_dat_adicionales
                     (cod_persona, parametro, val_parametro)
                   VALUES
                     (v_cod_persona, 'PER_IND_FATCA', p_fatca);
                  EXCEPTION
                    WHEN OTHERS THEN
                      p_mensaje     := 'Error al insertar parametro adicional de la persona';
                      p_cod_error   := 17;
                  END;
              END IF;

         END IF;
    END IF;

    IF p_cod_error = 0 THEN
       p_cod_persona := v_cod_persona;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_cod_error := 999;
      p_mensaje   := 'Error '||sqlerrm;
  END pr_alt_vin_fir_per_onb;

  PROCEDURE pr_alt_vinculo(p_cod_persona_emp in ba_personas.cod_persona%TYPE,
                           p_cod_persona     in ba_personas.cod_persona%TYPE,
                           p_tipo            in varchar2,
                           p_naturaleza      in ba_per_juridicas.naturaleza%TYPE,
                           p_cod_error       out number,
                           p_mensaje         out varchar2) IS

    v_cod_error   number(6);
    v_mensaje     varchar2(4000);
    v_log_mensaje varchar2(4000);
    v_existe_f    varchar2(1);
    v_existe_j    varchar2(1);
    v_existe_v    varchar2(1);
    v_naturaleza  ba_per_juridicas.naturaleza%TYPE;

  BEGIN

    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; END;

    if p_cod_persona_emp is null then
      p_mensaje   := 'La persona no puede ser nula.';
      p_cod_error := 1;
      return;
    end if;
    if p_cod_persona is null then
      p_mensaje   := 'La persona no puede ser nula.';
      p_cod_error := 2;
      return;
    end if;
    if p_tipo is null then
      p_mensaje   := 'El tipo no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;
    if p_naturaleza is null then
      p_mensaje   := 'La Naturaleza no puede ser nulo.';
      p_cod_error := 4;
      return;
    else
      v_naturaleza := fug_obt_tip_emp_onb(p_naturaleza);--NVB-2593
    end if;

    BEGIN
      Select 'S'
        into v_existe_j
        from ba_personas t
       where t.cod_persona = p_cod_persona_emp;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_mensaje   := 'No existe Persona ' || p_cod_persona_emp;
        p_cod_error := 5;
      WHEN OTHERS THEN
        p_cod_error   := 5;
        p_mensaje     := 'Error al buscar Persona ' || p_cod_persona_emp;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona_emp || ' ' ||
                         DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

    END;

    BEGIN
      Select 'S'
        into v_existe_f
        from ba_personas t
       where t.cod_persona = p_cod_persona;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        p_mensaje   := 'No existe Persona ' || p_cod_persona;
        p_cod_error := 6;
      WHEN OTHERS THEN
        p_cod_error   := 6;
        p_mensaje     := 'Error al buscar Persona ' || p_cod_persona;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona || ' ' ||
                         DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

    END;

    BEGIN
      Select 'S'
        into v_existe_v
        from ba_vinculos t
       where t.cod_persona = p_cod_persona_emp
         and t.cod_per_vinculo = p_cod_persona
         and t.activo = 'S';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe_v := 'N';
      WHEN OTHERS THEN
        p_cod_error   := 6;
        p_mensaje     := 'Error al buscar Vinculo ' || p_cod_persona || ' y ' || p_cod_persona_emp;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona || ' ' ||
                         DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

    END;
   if p_tipo = 'F' then
    BEGIN
      Select 'S'
        into v_existe_v
        from ba_vinculos t
       where t.cod_persona = p_cod_persona_emp
         and t.cod_per_vinculo = p_cod_persona
         and t.activo = 'S'
         and t.tipo='A';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe_v := 'N';
      WHEN OTHERS THEN
        p_cod_error   := 6;
        p_mensaje     := 'Error al buscar Vinculo ' || p_cod_persona || ' y ' || p_cod_persona_emp;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona || ' ' ||
                         DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

    END;

    if v_existe_v = 'S' then
      p_cod_error := 7;
      p_mensaje   := 'Ya se encuentra vinculada la persona ' ||
                     p_cod_persona || ' a ' || p_cod_persona_emp ||'con el tipo A';
    else
        BEGIN
          insert into ba_vinculos
            (COD_PERSONA,
             COD_PER_VINCULO,
             TIPO,
             ACTIVO,
             ESTADO,
       FEC_VENCIMIENTO)
          values
            (p_cod_persona_emp,
             p_cod_persona,
             'A',
             'S',
             'A',
       trunc(sysdate) + 365);
        EXCEPTION
          WHEN OTHERS THEN
            p_cod_error   := 8;
            p_mensaje     := 'Error al Insertar Vinculo ' || p_cod_persona_emp || ' y ' || p_cod_persona;
            v_log_mensaje := substr('Error al Insertar Vinculo ' || p_cod_persona || ' ' ||
                             DBMS_UTILITY.format_error_stack || ' - ' ||
                             DBMS_UTILITY.format_error_backtrace, 1, 4000);
            prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

        END;
      end if;
      end if;
         if p_tipo = 'U' then
    BEGIN
      Select 'S'
        into v_existe_v
        from ba_vinculos t
       where t.cod_persona = p_cod_persona_emp
         and t.cod_per_vinculo = p_cod_persona
         and t.activo = 'S'
         and t.tipo='OH';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_existe_v := 'N';
      WHEN OTHERS THEN
        p_cod_error   := 6;
        p_mensaje     := 'Error al buscar Vinculo ' || p_cod_persona || ' y ' || p_cod_persona_emp;
        v_log_mensaje := substr('Error al buscar Persona ' || p_cod_persona || ' ' ||
                         DBMS_UTILITY.format_error_stack || ' - ' ||
                         DBMS_UTILITY.format_error_backtrace, 1, 4000);
        prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

    END;

    if v_existe_v = 'S' then
      p_cod_error := 7;
      p_mensaje   := 'Ya se encuentra vinculada la persona ' ||
                     p_cod_persona || ' a ' || p_cod_persona_emp ||'con el tipo OH';
      else
        if v_naturaleza = fug_obt_pardinamico('VAL_MIN_EMP_UNI') then
          BEGIN
            insert into ba_vinculos
              (COD_PERSONA,
               COD_PER_VINCULO,
               TIPO,
               ACTIVO,
               ESTADO,
               COD_PERFIL)
            values
              (p_cod_persona_emp,
               p_cod_persona,
               'OH',
               'S',
               'A',
               'COMPLETO');
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error   := 8;
              p_mensaje     := 'Error al Insertar Vinculo ' ||
                               p_cod_persona_emp || ' y ' || p_cod_persona ||
                               ' Naturaleza: ' || v_naturaleza;
              v_log_mensaje := substr('Error al Insertar Vinculo ' || p_cod_persona || ' ' ||
                               DBMS_UTILITY.format_error_stack || ' - ' ||
                               DBMS_UTILITY.format_error_backtrace, 1, 4000);
              prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

          END;
        else
          BEGIN
            insert into ba_vinculos
              (COD_PERSONA,
               COD_PER_VINCULO,
               TIPO,
               ACTIVO,
               ESTADO,
               COD_PERFIL)
            values
              (p_cod_persona_emp,
               p_cod_persona,
               'OH',
               'S',
               'A',
               'CONSULTA');
          EXCEPTION
            WHEN OTHERS THEN
              p_cod_error   := 8;
              p_mensaje     := 'Error al Insertar Vinculo ' ||
                               p_cod_persona_emp || ' y ' || p_cod_persona ||
                               ' Naturaleza: ' || v_naturaleza;
              v_log_mensaje := substr('Error al Insertar Vinculo ' || p_cod_persona || ' ' ||
                               DBMS_UTILITY.format_error_stack || ' - ' ||
                               DBMS_UTILITY.format_error_backtrace, 1, 4000);
              prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO', v_log_mensaje, null, null);

          END;
        end if;
    end if;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      p_cod_error := 0;
      p_mensaje   := null;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      v_log_mensaje := substr(DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace, 1, 4000);
      p_cod_error   := 99;
      p_mensaje     := 'Ocurrio un error inesperado durante el proceso del alta de persona';
      prg_ins_log_programas('PAG_PLA.PR_ALT_VINCULO',
                            substr(v_log_mensaje, 1, 4000), null, null);
  END;

  /* Alta persona sin bloqueos en datos adicionales */
  PROCEDURE pr_alt_onb_persona(p_tipo              in ba_personas.tipo%type, -- fisica o juridica
                               p_nombres           in ba_personas.nom_completo%type,
                               p_apellidos         in ba_personas.nom_completo%type,
                               p_nro_documento     in ba_personas.nro_documento%type,
                               p_tip_documento     in ba_personas.cod_tip_documento%type,
                               p_est_civil         in ba_per_fisicas.est_civil%type,
                               p_fec_nacimiento    in ba_per_fisicas.fec_nacimiento%type,
                               p_cod_sexo          in ba_per_fisicas.cod_sexo%type,
                               p_fec_vto_documento in ba_personas.fec_vto_documento%type,
                               p_direccion         in ba_direcciones.direccion%type,
                               p_cod_ciudad        in ba_ciudades.cod_ciudad%type,
                               p_cod_pais_res      in ba_direcciones.cod_pais%type,
                               p_rub_primario      in ba_personas.cod_rub_primario%type,
                               p_num_celular       in ba_telefonos.telefono%type,
                               p_dir_correo        in ba_personas.dir_correo%type,
                               p_est_documento     in varchar2,
                               p_est_pru_vida      in varchar2,
                               p_cod_pai_nac       in ba_per_fisicas.cod_pai_nacionalidad%TYPE,
                               p_cod_ciu_nac       in ba_per_fisicas.cod_ciu_nacimiento%TYPE,
                               p_nro_casa          in ba_direcciones.numero%TYPE,
                               p_cal_secundaria    in ba_direcciones.direccion%TYPE,
                               p_cod_barrio        in ba_direcciones.cod_barrio%TYPE,
                               p_cod_departamento  in ba_direcciones.cod_departamento%TYPE,
                               p_piso              in ba_direcciones.piso%TYPE,
                               p_edificio          in ba_direcciones.edificio%TYPE,
                               p_referencias       in ba_direcciones.observacion%TYPE,
                               p_est_bancarizacion in varchar2,
                               p_usu_plataforma    in varchar2,
                               p_latitud           in ba_direcciones.latitud%TYPE DEFAULT null,
                               p_longitud          in ba_direcciones.longitud%TYPE DEFAULT null,
                               p_fec_emision       in ba_personas.fec_vto_documento%TYPE DEFAULT null,
                               p_est_match_doc     in varchar2,
                               p_es_pep            in varchar2,
                               p_isocr             in varchar2 default null,
                               p_ocupacion         in ba_per_fisicas.cod_profesion%type,
                               p_cod_pais_doc      in ba_personas.cod_pais%type,
                               p_cod_persona       out ba_personas.cod_persona%type,
                               p_est_verificacion  out varchar2,
                               p_cre_productos     out varchar2,
                               p_est_ios_excepcion out varchar2,
                               p_cod_error         out number,
                               p_mensaje           out varchar2)

   IS
    v_per_par_adicional  ba_tab_dat_adicionales.referencia%type;
    v_cod_persona        ba_personas.cod_persona%type;
    r_bpers              ba_personas%ROWTYPE;
    r_bperf              ba_per_fisicas%ROWTYPE;
    r_bperj              ba_per_juridicas%ROWTYPE;
    v_tip_persona        VARCHAR2(3);
    v_des_tip_persona    VARCHAR2(20);
    v_nombre             VARCHAR2(200);
    v_apellido           varchar2(200);
    v_direccion          ge_par_generales.dir_correo%type := fug_obt_pardinamico('DIR_ENV_MAI_ALT_PERSONA');
    v_retorno            varchar2(4000) := null;
    v_inhibido           varchar2(1) := 'N';
    v_edad               number;
    v_existe             number;
    v_exi_mail           varchar2(1);
    v_exi_cel            varchar2(1);
    v_exi_usu            varchar2(1);
    v_num_celular        ba_telefonos.telefono%type;
    v_dir_correo         ba_personas.dir_correo%type;
    v_usu_plataforma     varchar2(50);
    v_cod_error          number(6);
    v_mensaje            varchar2(4000);
    v_log_mensaje        varchar2(4000);
    v_pro_correcto       number := nvl(fug_obt_pardinamico('COD_MEN_SIN_ERROR'),
                                       0);
    v_fecha              date := pag_Cal.FU_OBT_FEC_ACTUAL(1);
    v_riesgo             varchar2(30);
    v_exi_circuito       varchar2(1);
    v_cod_barrio         ba_barrios.cod_barrio%type;
    v_dir_cumplimiento   ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('DIR_ENV_MAI_CUMPLIMIENTO');
    v_pri_nombre         ba_per_fisicas.pri_nombre%type;
    v_seg_nombre         ba_per_fisicas.seg_nombre%type;
    v_pri_apellido       ba_per_fisicas.pri_apellido%type;
    v_seg_apellido       ba_per_fisicas.seg_apellido%type;
    v_nom_completo       ba_personas.nom_completo%type;
    v_rub_primario       ge_rub_economicos.cod_rub_economico%type;
    v_es_inhibida        varchar2(1);
    v_cod_cau_alt_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_ALT_RIESGO',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);
    v_cod_cau_med_riesgo ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_MED_RIESGO',
                                                                                null,
                                                                                null,
                                                                                null,
                                                                                null);

    /*v_cod_cau_pep ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('COD_CAU_PEP',
                                                                             null,
                                                                             null,
                                                                             null,
                                                                             null);*/--DA-7917
  v_cod_cau_pep ge_per_inhibidas.cod_causa%type := fug_obt_pardinamico('PEP_ONBOARDING',
                                                                          null,
                                                                          null,
                                                                          null,
                                                                          null);

    v_exc_activo  varchar2(1) := fug_obt_pardinamico('ONB_EXCEPCION',
                                                     null,
                                                     null,
                                                     null,
                                                     null);
    v_gen_cir_49  varchar(1) := 'N';
    v_est_civil   varchar2(100);

    v_cod_causa         ge_per_inhibidas.cod_causa%type;
    v_per_existente     number := 0;
    v_fec_vto_documento ba_personas.fec_vto_documento%type;
    v_enc_lista         varchar(1) := 'N';
    v_per_par_telefono  ba_tab_dat_adicionales.referencia%type;
    v_per_par_correo    ba_tab_dat_adicionales.referencia%type;
    cursor c_cir_anteriores(p_cod_persona in ba_personas.cod_persona%type) is
      select w.cod_tip_circuito, w.cod_persona, w.cod_circuito
        from wf_circuitos w
       where estado not in ('C', 'F')
         and cod_tip_circuito in (37, 38, 39, 40, 41, 43, 44)
         and cod_persona = p_cod_persona;
    /* Verifico si el nombre ya existe */

    /* Procedimiento Principal*/
  BEGIN
    BEGIN
      PRE_INI_APLICACION;
      PAE_CNF.G_COD_MODULO := 1;
    END;
    v_retorno           := null;
    v_inhibido          := 'N';
    v_edad              := trunc((MONTHS_BETWEEN(v_fecha, p_fec_nacimiento) / 12));
    p_est_ios_excepcion := v_exc_activo;
    -- Validar que se hayan ingresado los datos obligatorios de acuerdo al tipo de persona.

    if p_nro_documento is null then
      -- nro_documento
      p_mensaje   := 'Numero de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_tip_documento is null then
      -- tipo de documento
      p_mensaje   := 'Tipo de documento no puede ser nulo.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_documento is null then
      -- estado de documento
      p_mensaje   := 'Estado de documento no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_pru_vida is null then
      -- estado de prueba de vida
      p_mensaje   := 'Estado de prueba de vida no puede ser nula.';
      p_cod_error := 3;
      return;
    end if;

    if p_est_match_doc is null then
      -- estado de prueba de vida
      p_mensaje   := 'Indicador de el indicador de coincidencia de prueba de vida y documento de identidad no puede ser vacio';
      p_cod_error := 3;
      return;
    end if;

    if p_cod_barrio is null then
      v_cod_barrio := fug_obt_pardinamico('COD_BAR_ONBOARDING');
      if v_cod_barrio is null then
        p_mensaje   := 'Barrio por defecto no parametrizado';
        p_cod_error := 4;
      end if;
    else
      v_cod_barrio := p_cod_barrio;
    end if;
    v_per_par_adicional := null;
    if p_num_celular is null and p_tipo = 'F' then
      -- numero de celular
      p_mensaje   := 'Numero de celular no puede ser nulo.';
      p_cod_error := 3;
      return;
    elsif p_num_celular is not null and p_tipo = 'F' then
      BEGIN
        SELECT DISTINCT referencia
          INTO v_per_par_telefono
          FROM ba_tab_dat_adicionales
         WHERE tab_relacion = 'BA_PERSONAS'
           AND val_parametro = p_num_celular
           AND parametro = 'CELULAR_ONBOARDING'
           and rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          v_per_par_telefono := 'N';
        WHEN others then
          p_mensaje     := 'Ocurrio un error al verificar numero celular:  ' ||p_num_celular;
          p_cod_error := 3;
          v_log_mensaje := substr('Ocurrio un error al verificar numero celular:  ' ||
                                  p_num_celular || ' ' || sqlerrm,1,4000);
      END;
    end if;

    if p_dir_correo is null and p_tipo = 'F' then
      -- correo electronico
      p_mensaje   := 'Direccion de correo no puede ser nula.';
      p_cod_error := 3;
      return;
    elsif p_dir_correo is not null and p_tipo = 'F' then
      BEGIN
        SELECT DISTINCT referencia
          INTO v_per_par_correo
          FROM ba_tab_dat_adicionales
         WHERE tab_relacion = 'BA_PERSONAS'
           AND val_parametro = p_dir_correo
           AND parametro = 'EMAIL_ONBOARDING'
           and rownum = 1;
      EXCEPTION
        WHEN no_data_found THEN
          v_per_par_correo := 'N';
        WHEN others then
          p_mensaje     := 'Ocurrio un error al verificar correo:  ' ||p_dir_correo;
          p_cod_error := 3;
          v_log_mensaje := substr('Ocurrio un error al verificar correo:  ' ||p_dir_correo || ' ' || sqlerrm,1,4000);

      END;

    end if;

    if p_est_pru_vida not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_pru_vida ||
                     ' invalido para la prueba de Vida (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_est_match_doc not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_match_doc ||
                     ' invalido (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_est_documento not in ('V', 'N') then
      p_mensaje   := 'Valor ' || p_est_documento ||
                     ' invalido para estado de documento (N: No validado, V: Verificado).';
      p_cod_error := 4;
    end if;

    if p_tipo not in ('F', 'M') and p_tipo is not null then
      p_mensaje   := 'Valor ' || p_tipo ||
                     ' invalido para tipo de persona (F: Fisica, J: Juridica).';
      p_cod_error := 4;
    end if;

    if p_rub_primario is not null and nvl(p_cod_error, 0) = 0 then
      BEGIN
        SELECT cod_rub_economico
          INTO v_rub_primario
          FROM ge_rub_economicos e
         WHERE cod_rub_economico =
               (select val_maximo
                  from ba_cod_referencias T
                 where t.dominio = 'ONB_OCUPACIONES'
                   and t.val_minimo = p_rub_primario);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          p_mensaje   := 'No existe rubro primario ' || p_rub_primario;
          p_cod_error := 4;
        WHEN OTHERS THEN
          p_mensaje     := 'Error al verificar rubro primario ' ||
                           p_rub_primario;
          v_log_mensaje := substr('Error al verificar rubro primario ' ||
                                  p_rub_primario || ' ' || sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      END;
    end if;

    --    da-657  control estado civil valido
    if p_est_civil is not null and p_tipo = 'F' then
      -- estado civil
      begin
        select 1
          into v_existe
          from ba_cod_referencias
         where dominio = 'COD_EST_CIVIL'
           and val_minimo = substr(p_est_civil, 1, 1);
        v_est_civil := p_est_civil;
      exception
        when no_data_found then
          v_log_mensaje := 'Estado civil ' || p_est_civil || ' no existe.';
          v_gen_cir_49  := 'S';
          v_est_civil   := 'SOLTERO';
        when others then
          p_mensaje     := 'Error al verificar estado civil. ';
          v_log_mensaje := substr('Error en estado civil. ' || p_est_civil || ' ' ||
                                  sqlerrm,
                                  1,
                                  4000);
          p_cod_error   := 4;
      end;
    end if;
    if nvl(v_cod_cau_pep, '0') = '0' or
       nvl(v_cod_cau_alt_riesgo, '0') = '0' or
       nvl(v_cod_cau_med_riesgo, '0') = '0' then
       p_mensaje   := 'Verificar no se encuentran configurados los parametros de causales COD_CAU_PEP,COD_CAU_ALT_RIESGO,COD_CAU_MED_RIESGO';
       p_cod_error := 99;
    end if;
    --
    if nvl(p_cod_error, 0) = 0 then
      BEGIN
        SELECT cod_persona
          INTO v_cod_persona
          FROM ba_personas
         WHERE cod_tip_documento = p_tip_documento
           AND nro_documento = trim(p_nro_documento);
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_persona := 'N';
          WHEN others then
            v_cod_persona := 'N';
      END;
      
      IF v_cod_persona IS NULL OR v_cod_persona ='N' THEN
        --Verifico Tipo Documento 11-OFICIOS JUDICIALES
        BEGIN
          SELECT cod_persona
            INTO v_cod_persona
            FROM ba_personas
           WHERE cod_tip_documento = 11
             AND nro_documento = trim(p_nro_documento);
        EXCEPTION
           WHEN no_data_found THEN
              v_cod_persona := 'N';
            WHEN others then
              v_cod_persona := 'N';
        END;
      END IF;   

      IF v_cod_persona = 'N' and nvl(p_cod_error, 0) = 0 THEN
        if p_tipo is null then
          -- tipo de persona
          p_mensaje   := 'Tipo de Persona no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_nombres is null then
          -- nombres
          p_mensaje   := 'Debe ingresar un Nombre.';
          p_cod_error := 3;
          return;
        end if;

        if p_apellidos is null and p_tipo = 'F' then
          -- apellidos
          p_mensaje   := 'Debe ingresar un Apellido.';
          p_cod_error := 3;
          return;
        end if;

        if p_est_civil is null and p_tipo = 'F' then
          -- estado civil
          p_mensaje   := 'Estado civil no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_fec_nacimiento is null and p_tipo = 'F' then
          -- fecha de nacimiento
          p_mensaje   := 'Fecha de nacimiento no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_cod_sexo is null and p_tipo = 'F' then
          -- sexo
          p_mensaje   := 'Sexo no puede ser nulo.';
          p_cod_error := 3;
          return;
        end if;

        if p_direccion is null then
          -- direccion
          p_mensaje   := 'Debe ingresar una direccion.';
          p_cod_error := 3;
          return;
        end if;

        IF p_cod_departamento is null THEN
          -- departamento
          p_mensaje   := 'Departamento no puede ser nulo.';
          p_cod_error := 3;
          return;
        END IF;

        if p_cod_ciudad is null then
          -- ciudad
          p_mensaje   := 'Ciudad no puede ser nula.';
          p_cod_error := 3;
          return;
        end if;

        if p_cod_pai_nac is null and p_tipo = 'F' then
          -- Nacionalidad
          p_mensaje   := 'Nacionalidad no debe de ser nula.';
          p_cod_error := 3;
          return;
        end if;

        IF p_cod_ciu_nac is null and p_tipo = 'F' THEN
          --Ciudad(Lugar) de Nacimiento
          p_mensaje   := 'Lugar de nacimiento no debe de ser nula.';
          p_cod_error := 3;
          return;
        END IF;

        if v_rub_primario is null then
          -- actividad economica
          p_mensaje   := 'Actividad economica no puede ser nula.';
          p_cod_error := 3;
          return;
        end if;
        -- vencimiento documento
        if p_fec_vto_documento is null and p_tipo = 'F' then
          if nvl(v_exc_activo, 'N') = 'S' then
            --contingencia biometria
            v_fec_vto_documento := to_date('01/01/2050', 'dd/mm/yyyy');
          else
            p_mensaje   := 'Vencimiento de documento no puede ser nulo.';
            p_cod_error := 3;
            return;
          end if;
        else
          v_fec_vto_documento := p_fec_vto_documento;
        end if;

        v_nombre                  := upper(TRIM(p_nombres));
        v_apellido                := upper(TRIM(p_apellidos));
        v_tip_persona             := p_tipo;
        r_bpers.nom_completo      := substr(v_nombre || ' ' || v_apellido,
                                            1,
                                            120);
        r_bpers.nro_documento     := upper(TRIM(p_nro_documento));
        r_bpers.fec_vto_documento := v_fec_vto_documento;
        r_bpers.cod_tip_documento := p_tip_documento;
        r_bpers.cod_rub_primario  := v_rub_primario;
        r_bpers.cod_actividad     := fug_obt_cod_actividad(v_rub_primario);
        r_bpers.cod_pais          := p_cod_pais_doc;
        r_bpers.dir_correo        := p_dir_correo;

        IF v_tip_persona = 'F' THEN
          r_bpers.tipo                 := 'F';
          r_bperf.pri_nombre           := fug_obt_nombre(v_nombre, 1);
          r_bperf.pri_apellido         := fug_obt_nombre(v_apellido, 1);
          r_bperf.seg_nombre           := fug_obt_nombre(v_nombre, 2);
          r_bperf.seg_apellido         := fug_obt_nombre(v_apellido, 2);
          r_bperf.est_civil            := substr(v_est_civil, 1, 1); --DA-6274 estado civil
          r_bperf.cod_sexo             := p_cod_sexo;
          r_bperf.fec_nacimiento       := p_fec_nacimiento;
          r_bperf.cod_pai_nacionalidad := p_cod_pai_nac;
          r_bperf.cod_ciu_nacimiento   := p_cod_ciu_nac;
          r_bperf.cod_profesion        := p_ocupacion;
        ELSE
          r_bpers.tipo          := 'J';
          r_bperj.raz_social    := TRIM(upper(substr(r_bpers.nom_completo,
                                                     1,
                                                     120)));
          r_bperj.nom_comercial := TRIM(upper(substr(r_bpers.nom_completo,
                                                     1,
                                                     65)));
        END IF;

        IF (r_bperf.pri_nombre IS NULL) AND r_bpers.tipo = 'F' THEN
          p_mensaje   := 'No se permite valores nulos para Primer Nombre';
          p_cod_error := 3;
          return;
        ELSIF (r_bperf.pri_apellido IS NULL) AND r_bpers.tipo = 'F' THEN
          p_mensaje   := 'No se permite valores nulos para Primer Apellido';
          p_cod_error := 3;
          return;
        ELSIF r_bperj.raz_social IS NULL AND r_bpers.tipo = 'J' THEN
          p_mensaje   := 'No se permite valores nulos para Razon Social';
          p_cod_error := 3;
          return;
        ELSIF r_bperj.nom_comercial IS NULL AND r_bpers.tipo = 'J' THEN
          p_mensaje   := 'No se permite valores nulos para Nombre Comercial';
          p_cod_error := 3;
          return;
        ELSE

          BEGIN
            SELECT cod_persona
              INTO v_cod_persona
              FROM ba_personas
             WHERE cod_tip_documento = p_tip_documento
               AND nro_documento = p_nro_documento;
          EXCEPTION
            WHEN no_data_found THEN
              v_cod_persona := null;
          END;

          IF nvl(v_cod_persona, 'X') = 'X' and nvl(p_cod_error, 0) = 0 THEN
            BEGIN
              --- No existe la persona
              SELECT s_cod_persona.nextval INTO v_cod_persona FROM dual;

              INSERT INTO ba_personas
                (cod_persona,
                 nom_completo,
                 tipo,
                 cod_tip_documento,
                 nro_documento,
                 cod_pais,
                 cod_rub_primario,
                 dir_correo,
                 fec_vto_documento,
                 cod_actividad)
              VALUES
                (v_cod_persona,
                 r_bpers.nom_completo,
                 r_bpers.tipo,
                 r_bpers.cod_tip_documento,
                 r_bpers.nro_documento,
                 r_bpers.cod_pais,
                 r_bpers.cod_rub_primario,
                 r_bpers.dir_correo,
                 r_bpers.fec_vto_documento,
                 r_bpers.cod_actividad);
              v_retorno := 'S';
            EXCEPTION
              WHEN OTHERS THEN
                p_mensaje     := 'Ocurrio un error al crear Persona ';
                v_log_mensaje := substr('Ocurrio un error al crear Persona ' ||
                                        SQLERRM || ' Nombre: ' ||
                                        r_bpers.nom_completo || ' Tipo: ' ||
                                        r_bpers.tipo || ' Tipo Doc: ' ||
                                        r_bpers.cod_tip_documento ||
                                        'Pais: ' || r_bpers.cod_pais ||
                                        ' Rub.Primario: ' ||
                                        r_bpers.cod_rub_primario ||
                                        ' Correo: ' || r_bpers.dir_correo ||
                                        ' Fecha vto.doc: ' ||
                                        r_bpers.fec_vto_documento ||
                                        ' Actividad: ' ||
                                        r_bpers.cod_actividad,
                                        1,
                                        4000);
                p_cod_error   := 99;
            END;
          END IF;
          v_retorno := null;
          if nvl(p_cod_error, 0) = 0 then
            IF r_bpers.tipo = 'F' THEN
              v_des_tip_persona := 'fisica';
              v_retorno         := fu_ins_ba_per_fisicas(v_cod_persona,
                                                         r_bperf);
            ELSE
              v_des_tip_persona := 'juridica';
              v_retorno         := fu_ins_ba_per_juridicas(v_cod_persona,
                                                           r_bperj);
            END IF;
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al crear persona ' ||
                               v_des_tip_persona;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            end if;
          end if;

          if nvl(p_cod_error, 0) = 0 and p_dir_correo is not null then

            begin
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 v_cod_persona,
                 'EMAIL_ONBOARDING',
                 p_dir_correo);
            EXCEPTION

              WHEN OTHERS THEN
                p_mensaje     := 'Error al insertar el correo ' ||
                                 p_dir_correo || ' como dato adicional ';
                v_log_mensaje := substr('Error al insertar el correo ' ||p_dir_correo ||' como dato adicional ' || sqlerrm,1,4000);
                p_cod_error   := 99;
            END;

          end if;
          v_retorno := null;
          if nvl(p_cod_error, 0) = 0 then
            v_retorno := fu_ins_dir_onb_persona(v_cod_persona,
                                                p_cod_pais_res,
                                                p_cod_ciudad,
                                                p_direccion,
                                                p_nro_casa,
                                                p_cal_secundaria,
                                                v_cod_barrio,
                                                p_cod_departamento,
                                                p_piso,
                                                p_edificio,
                                                p_referencias,
                                                p_latitud,
                                                p_longitud);
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al guardar direccion ';
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            end if;
          end if;
          v_retorno := null;
          IF p_num_celular is not null and nvl(p_cod_error, 0) = 0 THEN
            v_retorno := fu_ins_tel_persona(v_cod_persona, p_num_celular);
            if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Error al insertar telefono ' ||p_num_celular;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
            else
              BEGIN
                INSERT INTO ba_tab_dat_adicionales
                  (tab_relacion, referencia, parametro, val_parametro)
                VALUES
                  ('BA_PERSONAS',
                   v_cod_persona,
                   'CELULAR_ONBOARDING',
                   p_num_celular);
              EXCEPTION
                WHEN OTHERS THEN
                  if nvl(v_retorno, 'N') = 'S' then
                    p_mensaje     := 'Error al insertar el nro celuldar ' ||
                                     p_num_celular ||
                                     ' como dato adicional ';
                    v_log_mensaje := substr('Error al insertar el nro celuldar ' ||
                                            p_num_celular ||' como dato adicional ' ||sqlerrm,1,4000);
                    p_cod_error   := 99;
                  end if;
              END;
            end if;
          END IF;

          if nvl(p_cod_error, 0) = 0 then
            if p_usu_plataforma is not null then
              BEGIN
                INSERT INTO ba_tab_dat_adicionales
                  (tab_relacion, referencia, parametro, val_parametro)
                VALUES
                  ('GE_CLIENTES',
                   v_cod_persona,
                   'GEN_COD_USU_PLATAFORMA',
                   p_usu_plataforma);
              EXCEPTION
                WHEN OTHERS THEN
                  p_mensaje     := 'Error al insertar usuario plataforma ' ||
                                   p_usu_plataforma ||
                                   ' como dato adicional ';
                  v_log_mensaje := substr('Error al insertar usuario plataforma ' ||
                                          p_usu_plataforma ||' como dato adicional ' ||sqlerrm,1,4000);
                  p_cod_error   := 99;
              END;
            end if;
          end if;
        end if;

        ---Actualizo/libero el telefono de la persona anterior
        IF nvl(v_per_par_telefono, 'X') != 'N' and nvl(p_cod_error, 0) = 0 then
          pr_upd_ant_onb_telefono(v_per_par_telefono,
                                  p_dir_correo,
                                  p_num_celular,
                                  p_usu_plataforma,
                                  v_cod_error,
                                  v_log_mensaje);
          if nvl(v_cod_error, 0) != 0 then
            p_mensaje   := 'Error al actualizar parametro onboarding. Cod Error: ' ||v_cod_error;
            p_cod_error := 99;
          end if;
        END IF;
        ---Actualizo/libero el correo de la persona anterior
        IF nvl(v_per_par_correo, 'X') != 'N' and nvl(p_cod_error, 0) = 0 then
          pr_upd_ant_onb_correo(v_per_par_correo,
                                p_dir_correo,
                                p_num_celular,
                                p_usu_plataforma,
                                v_cod_error,
                                v_log_mensaje);
          if nvl(v_cod_error, 0) != 0 then
            p_mensaje   := 'Error al actualizar parametro onboarding. Cod Error: ' ||v_cod_error;
            p_cod_error := 99;
          end if;
        END IF;

      ELSE
        p_cod_persona := v_cod_persona;
        IF nvl(p_cod_error, 0) = 0 THEN
          IF p_tipo = 'F' THEN
            ---
             v_nombre                     := upper(TRIM(p_nombres));
             v_apellido                   := upper(TRIM(p_apellidos));
             r_bperf.pri_nombre           := fug_obt_nombre(v_nombre, 1);
             r_bperf.pri_apellido         := fug_obt_nombre(v_apellido, 1);
             r_bperf.seg_nombre           := fug_obt_nombre(v_nombre, 2);
             r_bperf.seg_apellido         := fug_obt_nombre(v_apellido, 2);
             r_bperf.fec_nacimiento       := p_fec_nacimiento;
             r_bperf.cod_profesion        := p_ocupacion;
            ---
            v_des_tip_persona := 'fisica';
            v_retorno         := fu_ins_ba_per_fisicas(v_cod_persona,
                                                       r_bperf);
          END IF;
          if nvl(v_retorno, 'N') != 'S' then
              p_mensaje     := 'Ocurrio un error al actualizar persona '|| v_des_tip_persona;
              v_log_mensaje := nvl(v_retorno, p_mensaje);
              p_cod_error   := 99;
          end if;
          v_existe := null;
          --verifico si ya tiene productos activos
          begin
            select 1
              into v_existe
              from ge_cta_clientes c
              left outer join ah_cta_vistas v
                on c.nro_cuenta = v.nro_cuenta
              left outer join pr_cta_prestamos p
                on p.nro_cuenta = c.nro_cuenta
              left outer join ta_cta_tarjetas t
                on c.nro_cuenta = t.nro_cuenta
             where c.cod_persona = v_cod_persona
               and c.relacion = 'P'
               and (v.estado not in ('C', 'P') or p.estado != 'N' or
                   t.estado != 'C');
          exception
            when no_data_found then
              v_existe := 0;
            when too_many_rows then
              v_existe := 1;
            when others then
              p_cod_error   := 99;
              p_mensaje     := 'Error al verificar productos activos de la persona ' ||
                               v_cod_persona;
              v_log_mensaje := substr('Error al verificar productos activos de la persona ' ||
                                      v_cod_persona || ' - ' || sqlerrm,
                                      1,
                                      4000);
          end;

          --Si la persona existe y no tiene productos activos entonces actualizar Email
          --Teléfono Dirección Profesión DA-4820
          if nvl(v_existe, 999) = 0 and nvl(p_cod_error, 0) = 0 then
            pr_act_dat_onb_persona(v_cod_persona,
                                   v_rub_primario,
                                   p_direccion,
                                   p_cod_pais_res,
                                   p_cod_ciudad,
                                   p_nro_casa,
                                   p_cal_secundaria,
                                   p_cod_barrio,
                                   p_cod_departamento,
                                   p_piso,
                                   p_edificio,
                                   p_referencias,
                                   p_num_celular,
                                   p_dir_correo,
                                   p_latitud,
                                   p_longitud,
                                   v_cod_error,
                                   v_log_mensaje);

            if nvl(v_cod_error, 0) != 0 then
              p_cod_error := 99;
              p_mensaje   := 'Error al actualizar datos de la persona ' ||
                             v_cod_persona;
            end if;
          end if;
          ---Flujo de persona existente
          IF nvl(v_cod_persona, 'X') != 'N' and
             (nvl(v_per_par_telefono, 'X') != 'N' or nvl(v_per_par_correo, 'X') != 'N')  THEN
            v_per_existente := 1;

            --Actualiza los datos de la persona datos adicionales
            IF nvl(p_cod_error, 0) = 0 then
              pr_upd_dat_onboarding(v_cod_persona,
                                    p_dir_correo,
                                    p_num_celular,
                                    p_usu_plataforma,
                                    v_cod_error,
                                    v_log_mensaje);
              if nvl(v_cod_error, 0) != 0 then
                p_mensaje   := 'Error al insertar parametro onboarding. Cod Error: ' ||v_cod_error;
                p_cod_error := 99;
              end if;
            END IF;

            --Verifico si tiene datos adicionales telefono
            IF (v_cod_persona != v_per_par_telefono) THEN
             ---Actualizo/libero el telefono de la persona anterior
                IF nvl(v_per_par_telefono, 'X') != 'N' and nvl(p_cod_error, 0) = 0 then
                  pr_upd_ant_onb_telefono(v_per_par_telefono,
                                          p_dir_correo,
                                          p_num_celular,
                                          p_usu_plataforma,
                                          v_cod_error,
                                          v_log_mensaje);
                  if nvl(v_cod_error, 0) != 0 then
                    p_mensaje   := 'Error al actualizar parametro onboarding telefono. Cod Error: ' ||v_cod_error;
                    p_cod_error := 99;
                  end if;
                END IF;
            END IF;

            --Verifico si tiene datos adicionales correo
            IF (v_cod_persona != v_per_par_correo) THEN
               ---Actualizo/libero el correo de la persona anterior
                IF nvl(v_per_par_correo, 'X') != 'N' and nvl(p_cod_error, 0) = 0 then
                  pr_upd_ant_onb_correo(v_per_par_correo,
                                        p_dir_correo,
                                        p_num_celular,
                                        p_usu_plataforma,
                                        v_cod_error,
                                        v_log_mensaje);
                  if nvl(v_cod_error, 0) != 0 then
                    p_mensaje   := 'Error al actualizar parametro onboarding correo. Cod Error: ' ||v_cod_error;
                    p_cod_error := 99;
                  end if;
                END IF;
            END IF;

            --Inserto si no existe registro en datos adicionales
            IF (v_cod_persona != v_per_par_correo or v_cod_persona != v_per_par_telefono) THEN
                v_dir_correo := p_dir_correo;
                v_num_celular := p_num_celular;
                v_usu_plataforma := p_usu_plataforma;

              IF nvl(p_cod_error, 0) = 0 then
                pr_ins_dat_onboarding(v_cod_persona,
                                      v_dir_correo,
                                      v_num_celular,
                                      v_usu_plataforma,
                                      v_cod_error,
                                      v_log_mensaje);
                if nvl(v_cod_error, 0) != 0 then
                  p_mensaje   := 'Error al insertar parametro onboarding. Cod Error: ' ||v_cod_error;
                  p_cod_error := 99;
                end if;
              END IF;
            END IF;

          ELSIF (v_per_par_telefono = 'N' or v_per_par_correo= 'N') and
                nvl(v_cod_persona, 'X') != 'N' THEN
            /*Persona existente sin parametros onboarding*/
            v_per_existente := 1;
            v_dir_correo := p_dir_correo;
            v_num_celular := p_num_celular;
            v_usu_plataforma := p_usu_plataforma;

            --Actualiza los datos de la persona en datos adicionales si existe
            IF nvl(p_cod_error, 0) = 0 then
              pr_upd_dat_onboarding(v_cod_persona,
                                    v_dir_correo,
                                    v_num_celular,
                                    v_usu_plataforma,
                                    v_cod_error,
                                    v_log_mensaje);
              if nvl(v_cod_error, 0) != 0 then
                p_mensaje   := 'Error al insertar parametro onboarding. Cod Error: ' ||v_cod_error;
                p_cod_error := 99;
              end if;
            END IF;

            IF nvl(p_cod_error, 0) = 0 then
              pr_ins_dat_onboarding(v_cod_persona,
                                    v_dir_correo,
                                    v_num_celular,
                                    v_usu_plataforma,
                                    v_cod_error,
                                    v_log_mensaje);
              if nvl(v_cod_error, 0) != 0 then
                p_mensaje   := 'Error al insertar parametro onboarding. Cod Error: ' ||
                               v_cod_error;
                p_cod_error := 99;
              end if;
            END IF;
          END IF;
          --Actualiza el tipo de documento
          if nvl(p_cod_error, 0) = 0 and v_cod_persona != 'N' then
                begin
                 update ba_personas p
                    set p.cod_tip_documento = p_tip_documento,
                        p.fec_vto_documento = p_fec_vto_documento,
                        p.cod_pais          = p_cod_pais_doc
                  where p.cod_persona = p_cod_persona;
               end;
               begin
                 update ba_per_fisicas
                    set fec_nacimiento       = p_fec_nacimiento,
                        cod_profesion        = p_ocupacion,
                        est_civil            = substr(p_est_civil, 1, 1),
                        cod_sexo             = p_cod_sexo,
                        cod_pai_nacionalidad = p_cod_pai_nac,
                        cod_ciu_nacimiento   = p_cod_ciu_nac
                  where cod_persona = p_cod_persona;
               end;
          end if ;          
        END IF;        
      END IF;

      v_retorno := null;
      if nvl(p_cod_error, 0) = 0 then
        if nvl(p_isocr, 'N') = 'S' then
          begin
            insert into ba_per_dat_adicionales
              (cod_persona, parametro, val_parametro)
            values
              (v_cod_persona, 'ONB_CON_OCR', p_isocr);
          exception
            when others then
              p_mensaje     := 'Error al insertar parametro adicional de la persona';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al insertar parametro adicional de la persona ' ||
                                      sqlerrm,
                                      1,
                                      4000);
          end;
          if nvl(p_cod_error, 0) = 0 then
            --if paw_cir.fu_ini_circuito(52, v_cod_persona, v_cod_persona) <> 0 then
            if paw_cir.fu_ini_circuito(37, v_cod_persona, v_cod_persona) <> 0 then
              p_mensaje     := 'Error al iniciar el Circuito de Verificación de lectura OCR';
              p_cod_error   := 99;
              v_log_mensaje := substr('Error al iniciar el Circuito de Verificación de lectura OCR ' ||
                                      paw_cir.G_MSJ_ERROR,
                                      1,
                                      4000);

            else
              p_est_verificacion := 'P';
            end if;
          end if;
        end if;
        /*Circuito de contingencia*/
        if nvl(v_exc_activo, 'N') = 'S' then
          if paw_cir.fu_ini_circuito(45, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Documentos';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Documentos ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          end if;
        end if;
        /*Circuito verificacion de estado civil en c.i.DA-6274*/
        if nvl(v_gen_cir_49, 'N') = 'S' then
          if paw_cir.fu_ini_circuito(49, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion del estado civil en c.i.';
            p_cod_error   := 99;
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion del estado civil en c.i. ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
          end if;
        end if;
        if p_est_documento = 'N' and nvl(v_exc_activo, 'N') = 'N' then
          if paw_cir.fu_ini_circuito(37, v_cod_persona, v_cod_persona) <> 0 then
            p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Imagen subida por la persona';
            v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Imagen subida por la persona ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
            p_cod_error   := 99;
          else
            p_est_verificacion := 'P';
          end if;
        elsif p_est_documento = 'V' then
          --cedula frente
          v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                            null,
                                                            125,
                                                            v_fec_vto_documento,
                                                            null,
                                                            null);
          if nvl(v_retorno, 'N') = 'S' then
            --cedula reverso
            v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                              null,
                                                              126,
                                                              v_fec_vto_documento,
                                                              null,
                                                              null);
          end if;
          if nvl(v_retorno, 'N') != 'S' then
            p_mensaje     := 'Error al insertar el registro de la imagen para la persona ';
            v_log_mensaje := nvl(v_retorno, p_mensaje);
            p_cod_error   := 99;
          end if;
        end if;        
      end if;      
    end if;

    --Se solicita verificacion de prueba de vida
    --cod_tip_documento 126 en ba_cod_referencias dominio tip_per_documento
    v_retorno := null;
    if nvl(p_cod_error, 0) = 0 then
      if p_est_pru_vida = 'N' and nvl(v_exc_activo, 'N') = 'N' then
        if paw_cir.fu_ini_circuito(39, v_cod_persona, v_cod_persona) <> 0 then
          p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Prueba de vida';
          p_cod_error   := 99;
          v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Prueba de vida ' ||
                                  paw_cir.G_MSJ_ERROR,
                                  1,
                                  4000);

        else
          p_est_verificacion := 'P';
        end if;
      elsif p_est_pru_vida = 'V' then
        v_retorno := pag_pla.fu_ins_ba_per_ima_documentos(v_cod_persona,
                                                          null,
                                                          127,
                                                          v_fec_vto_documento,
                                                          null,
                                                          null);
        if nvl(v_retorno, 'N') != 'S' then
          p_mensaje     := 'Error al insertar registro para imagen de prueba de vida';
          v_log_mensaje := nvl(v_retorno, p_mensaje);
          p_cod_error   := 99;
        end if;
      end if;
    end if;
    
    if v_fec_vto_documento < v_fec_actual and nvl(p_cod_error, 0) = 0 then
      if paw_cir.fu_ini_circuito(41, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje     := 'Error al iniciar el Circuito de Verificacion de Documento vencido';
        p_cod_error   := 99;
        v_log_mensaje := substr('Error al iniciar el Circuito de Verificacion de Documento vencido ' ||
                                paw_cir.G_MSJ_ERROR,
                                1,
                                4000);
      else
        p_est_verificacion := 'P';
      end if;

    end if;

   
    /*Circuito de menor de edad*/
    IF v_edad < nvl(to_number(fug_obt_pardinamico('BA_MAY_EDAD')), 0) and
       nvl(p_cod_error, 0) = 0 THEN
      if paw_cir.fu_ini_circuito(42, v_cod_persona, v_cod_persona) <> 0 then
        p_mensaje   := 'Error al iniciar el Circuito de Menor de edad';
        p_cod_error := 99;
      else
        for rec in c_cir_anteriores(v_cod_persona) loop
          if paw_cir.FU_CAN_CIR_PENDIENTES(rec.cod_tip_circuito,
                                           rec.cod_persona) <> 0 then
            p_mensaje     := 'Error al cancelar circuito tipo: ' ||
                             rec.cod_tip_circuito;
            v_log_mensaje := substr('Error al cancelar circuito tipo: ' ||
                                    rec.cod_tip_circuito || ' ' ||
                                    paw_cir.G_MSJ_ERROR,
                                    1,
                                    4000);
            p_cod_error   := 99;
            exit;
          end if;
          if rec.cod_tip_circuito in (44, 38) then
            update ge_per_inhibidas i
               set i.estado = 'D'
             where i.estado = 'I'
               and i.cod_causa in
                   (v_cod_cau_pep,
                    fug_obt_pardinamico('COD_CAU_BLO_ALT_PER'))
               and i.cod_persona = rec.cod_persona;
          end if;

        end loop;
        if nvl(p_cod_error, 0) = 0 then
          p_est_verificacion := 'P';
        end if;
      end if;
    END IF;
    if nvl(p_cod_error, 0) = 0 then
      -- En el caso que ambos estados no sean validos, el campo EST_VERIFICACION,
      -- debe ser Sin Verificacion.
      if nvl(p_est_verificacion, 'X') = 'P' then

        update ba_personas
           set est_verificacion = 'N' -- Sin verificacion
         where cod_persona = v_cod_persona;
        p_cre_productos := 'N'; --No se crea producto
      elsif ((p_est_documento = 'V' and p_est_pru_vida = 'V' and
            p_est_match_doc = 'V') or nvl(p_est_verificacion, 'X') = 'V') then
        -- Si los dos estados son validos. el campo EST_VERIFICACION debe ser Verificado..
        update ba_personas
           set est_verificacion = 'V' -- Verificado
         where cod_persona = v_cod_persona;
        p_est_verificacion := 'V';
        p_cre_productos    := 'S';
      elsif nvl(v_enc_lista, 'N') = 'N' and nvl(p_es_pep, 'N') = 'S' then
        --si creó circuito 38 por encontrarse coincidencias
        update ba_personas
           set est_verificacion = 'V' -- Verificado
         where cod_persona = v_cod_persona;
        p_cre_productos    := 'S'; --Si crea producto
        p_est_verificacion := 'V';
      elsif nvl(v_exc_activo, 'N') = 'S' and
            (p_est_documento = 'N' or p_est_pru_vida = 'N' or
             p_est_match_doc = 'N') then

        update ba_personas
           set est_verificacion = 'V'
         where cod_persona = v_cod_persona;
        p_est_verificacion := 'V';
        p_cre_productos    := 'S';
      end if;      
    end if;
    v_cod_error := null;
    v_mensaje   := null;
    if nvl(p_cod_error, 0) = 0 and v_cod_persona != 'N' and
       p_dir_correo is not null and p_est_verificacion = 'P' then
      pr_env_not_onboarding(v_cod_persona,
                            p_nro_documento,
                            p_dir_correo,
                            fug_obt_pardinamico('ONB_MAI_BIE_TEMPLATE'),
                            v_cod_error,
                            v_mensaje);
    end if;

    if nvl(p_cod_error, 0) != 0 and
       nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
      p_cod_persona := null;
      prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                            substr('Documento Nro. ' || p_nro_documento ||
                                   ' Error: ' ||
                                   nvl(v_log_mensaje, p_mensaje),
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
      rollback;
    elsif nvl(v_log_mensaje, 'X') != 'X' then
      prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                            substr('Documento Nro. ' || p_nro_documento ||
                                   ' Error: ' || v_log_mensaje,
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;  

    if v_cod_persona != 'N' and nvl(p_cod_error, 0) = 0 then
      p_cod_persona := v_cod_persona;
      p_mensaje     := null;
      p_cod_error   := 0;
    end if;

  EXCEPTION
    WHEN OTHERS THEN
      v_log_mensaje := substr('Error al procesar el alta de la persona ' ||
                              DBMS_UTILITY.format_error_stack || ' - ' ||
                              DBMS_UTILITY.format_error_backtrace,
                              1,
                              4000);
      p_cod_error   := 99;
      p_mensaje     := 'Ocurrio un error inesperado durante el proceso del alta de persona';
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                              substr('Documento Nro. ' || p_nro_documento ||
                                     ' Error: ' ||
                                     nvl(v_log_mensaje, p_mensaje),
                                     1,
                                     4000),
                              null,
                              null);
      end if;
      rollback;
  END;

  /* Actualiza datos del onboarding */
  PROCEDURE pr_upd_dat_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2) is
    v_existe varchar2(1);
    v_existe2 varchar2(1);

  begin
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    if p_cod_persona is null then
      p_mensaje   := 'El codigo persona no puede ser nulo ';
      p_cod_error := 1;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_nro_celular is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_existe:='N';
            END;
      if v_existe='S' then
        BEGIN
           UPDATE ba_tab_dat_adicionales
              SET val_parametro=p_nro_celular
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona;
         END;
      end if;
     end if;
    end if;

    if nvl(p_cod_error, 0) = 0 then
      if p_correo is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe2
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
          WHEN others then
            v_existe2:='N';
        END;
       if v_existe2='S' then
        BEGIN
           UPDATE ba_tab_dat_adicionales
              SET val_parametro=p_correo
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona;
         END;
       end if;
      end if;
    end if;

  exception
    when others then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                              substr(sqlerrm || ' Correo: ' || p_correo ||
                                     ' Celular: ' || p_nro_celular ||
                                     ' Usuario: ' || p_usu_plataforma,
                                     1,4000),p_cod_persona,null);
      end if;
  end pr_upd_dat_onboarding;

  /* Libera el registro anterior para utilizar telefono */
  PROCEDURE pr_upd_ant_onb_telefono(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2) is
    v_existe varchar2(1);

  begin
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    if p_cod_persona is null then
      p_mensaje   := 'El codigo persona no puede ser nulo ';
      p_cod_error := 1;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_nro_celular is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
            WHEN OTHERS THEN
               v_existe:='N';
            END;
      if v_existe='S' then
        BEGIN
          UPDATE ba_tab_dat_adicionales
             SET val_parametro = '0'
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona;
        END;
        BEGIN
           UPDATE ba_telefonos
              SET telefono = '0'
            WHERE (telefono = p_nro_celular or
                  area || telefono = p_nro_celular or
                  telefono = replace(p_nro_celular, '+595', '0'))
              AND cod_persona = p_cod_persona
              AND rownum = 1;
        END;
      end if;
     end if;
    end if;
  exception
    when others then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                              substr(sqlerrm || ' Correo: ' || p_correo ||
                                     ' Celular: ' || p_nro_celular ||
                                     ' Usuario: ' || p_usu_plataforma,
                                     1,4000),p_cod_persona,null);
      end if;
  end pr_upd_ant_onb_telefono;

  /* Libera el registro anterior para utilizar correo */
  PROCEDURE pr_upd_ant_onb_correo(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2) is
    v_existe varchar2(1);

  begin
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
    if p_cod_persona is null then
      p_mensaje   := 'El codigo persona no puede ser nulo ';
      p_cod_error := 1;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_correo is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
          WHEN others then
            v_existe:='N';
        END;
       if v_existe='S' then
        BEGIN
          UPDATE ba_tab_dat_adicionales
             SET val_parametro = '0'
           WHERE tab_relacion = 'BA_PERSONAS'
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona;
        END;
        BEGIN
          UPDATE ba_personas
             SET dir_correo = '0'
           WHERE cod_persona = p_cod_persona;
        END;
       end if;
      end if;
    end if;

  exception
    when others then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                              substr(sqlerrm || ' Correo: ' || p_correo ||
                                     ' Celular: ' || p_nro_celular ||
                                     ' Usuario: ' || p_usu_plataforma,
                                     1,4000),p_cod_persona,null);
      end if;
  end pr_upd_ant_onb_correo;

   /* Inserta registro en datos adicionales */
  PROCEDURE pr_ins_dat_onboarding(p_cod_persona    in ba_personas.cod_persona%type,
                                  p_correo         in ba_tab_dat_adicionales.val_parametro%type,
                                  p_nro_celular    in ba_tab_dat_adicionales.val_parametro%type,
                                  p_usu_plataforma in ba_tab_dat_adicionales.val_parametro%type,
                                  p_cod_error      out number,
                                  p_mensaje        out varchar2) is
    v_existe varchar2(1);
  begin
    if p_cod_persona is null then
      p_mensaje   := 'El codigo persona no puede ser nulo ';
      p_cod_error := 1;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_nro_celular is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND val_parametro = p_nro_celular
             AND parametro = 'CELULAR_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 p_cod_persona,
                 'CELULAR_ONBOARDING',
                 p_nro_celular);
            END;
        END;
      end if;
    end if;

    if nvl(p_cod_error, 0) = 0 then
      if p_correo is not null then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'BA_PERSONAS'
             AND val_parametro = p_correo
             AND parametro = 'EMAIL_ONBOARDING'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('BA_PERSONAS',
                 p_cod_persona,
                 'EMAIL_ONBOARDING',
                 p_correo);
            END;
        END;
      end if;
    end if;
    if nvl(p_cod_error, 0) = 0 then
      if p_usu_plataforma is not null and nvl(p_cod_error, 0) = 0 then
        BEGIN
          SELECT DISTINCT 'S'
            INTO v_existe
            FROM ba_tab_dat_adicionales
           WHERE tab_relacion = 'GE_CLIENTES'
             AND val_parametro = p_usu_plataforma
             AND parametro = 'GEN_COD_USU_PLATAFORMA'
             and referencia = p_cod_persona
             and rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
            BEGIN
              INSERT INTO ba_tab_dat_adicionales
                (tab_relacion, referencia, parametro, val_parametro)
              VALUES
                ('GE_CLIENTES',
                 p_cod_persona,
                 'GEN_COD_USU_PLATAFORMA',
                 p_usu_plataforma);
            END;
        END;

      end if;
    end if;
    if nvl(p_cod_error, 0) != 0 then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',p_mensaje,p_cod_persona,null);
      end if;
    end if;
  exception
    when others then
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' then
        prg_ins_log_programas('PAG_PLA.PR_ALT_ONB_PERSONA',
                              substr(sqlerrm || ' Correo: ' || p_correo ||
                                     ' Celular: ' || p_nro_celular ||
                                     ' Usuario: ' || p_usu_plataforma,
                                     1,
                                     4000),
                              p_cod_persona,
                              null);
      end if;
  end pr_ins_dat_onboarding;
  
  procedure pr_act_dat_onb_persona(p_cod_persona      in ba_personas.cod_persona%type,
                                   p_profesion        in ba_personas.cod_rub_primario%type,
                                   p_direccion        in ba_direcciones.direccion%type,
                                   p_cod_pais_res     in ba_direcciones.cod_pais%type,
                                   p_cod_ciudad       in ba_direcciones.cod_ciudad%type,
                                   p_nro_casa         IN ba_direcciones.numero%TYPE,
                                   p_cal_secundaria   IN ba_direcciones.direccion%TYPE,
                                   p_cod_barrio       IN ba_direcciones.cod_barrio%TYPE,
                                   p_cod_departamento IN ba_direcciones.cod_departamento%TYPE,
                                   p_piso             IN ba_direcciones.piso%TYPE,
                                   p_edificio         IN ba_direcciones.edificio%TYPE,
                                   p_referencias      IN ba_direcciones.observacion%TYPE,
                                   p_telefono         in VARCHAR2,
                                   p_correo           in ba_personas.dir_correo%type,
                                   p_latitud          in ba_direcciones.latitud%TYPE,
                                   p_longitud         in ba_direcciones.longitud%TYPE,
                                   p_cod_error        out number,
                                   p_mensaje          out varchar2) is
    v_existe   varchar2(1);
    v_retorno  varchar2(4000);
    v_cod_pais_res ba_direcciones.cod_pais%type;
    v_cantidad number := 0;
    v_existe_per varchar2(1);
    v_existe_dir varchar2(1);
  begin
    if p_profesion is null then
      p_cod_error := 3;
      p_mensaje   := 'El rubro primario no puede ser null';
    end if;
    if p_direccion is null then
      p_cod_error := 3;
      p_mensaje   := 'La direccion no puede ser null';
    end if;
    if p_cod_pais_res is null then
      v_cod_pais_res := fu_obt_cod_pais(p_cod_departamento, p_cod_ciudad);
      if v_cod_pais_res is null then
        p_cod_error := 3;
        p_mensaje   := 'El codigo de pais no puede ser null';
      end if;
    end if;
    if p_cod_ciudad is null then
      p_cod_error := 3;
      p_mensaje   := 'El codigo de ciudad no puede ser null';
    end if;

    begin
      pre_ini_aplicacion;
      pae_cnf.g_cod_modulo := 1;
    end;
    if p_profesion is not null and p_correo is not null then
      --Se actualiza rubro / correo
      update ba_personas p
         set p.dir_correo = p_correo, p.cod_rub_primario = p_profesion
       where p.cod_persona = p_cod_persona;
    end if;
    if p_telefono is not null then
      v_existe  := null;
      v_retorno := null;
      begin
         select 'S'
          into v_existe
          from ba_telefonos t
         where (t.telefono = p_telefono or
               t.area || t.telefono = p_telefono or
              t.telefono = replace(p_telefono,'+595','0'))
           and t.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          v_existe := 'S';
        when others then
          p_cod_error := 3;
          p_mensaje   := substr('Error al recuperar telefonos de la persona ' ||
                                p_cod_persona || ' Telefono ' || p_telefono ||
                                ' - ' || sqlerrm,
                                1,
                                4000);
      end;

      savepoint telefono;
      --se deja todos los nros como no principal
      update ba_telefonos
         set principal = 'N'
       where cod_persona = p_cod_persona
         and principal = 'S';
      if nvl(v_existe, 'N') = 'S' then
        ---buscamos registro de Tipo P = Personal
         begin
           select 'S'
            into v_existe_per
            from ba_telefonos t
           where (t.telefono = p_telefono or
                 t.area || t.telefono = p_telefono or
                t.telefono = replace(p_telefono,'+595','0'))
             and t.cod_persona = p_cod_persona
             and t.tipo='P';
        exception
          when no_data_found then
            v_existe_per := 'N';
          when too_many_rows then
            v_existe_per := 'S';
         end;

        if v_existe_per='S' then
        -- actualiza el registro Tipo Personal como principal
          update ba_telefonos
             set principal = 'S', tipo = 'P'
           where (telefono = p_telefono or area || telefono = p_telefono or
                 telefono = replace(p_telefono,'+595','0'))
             and cod_persona = p_cod_persona
             and tipo='P'
             and rownum = 1;
        else
          -- actualiza el registro que retorna como principal
          update ba_telefonos
           set principal = 'S', tipo = 'P'
         where (telefono = p_telefono or area || telefono = p_telefono or
               telefono = replace(p_telefono,'+595','0'))
           and cod_persona = p_cod_persona
           and rownum = 1;
        end if;

        if sql%rowcount = 0 then
          p_cod_error := 99;
          p_mensaje   := 'No se pudo actualizar el telefono ' || p_telefono ||
                         ' como principal';
          rollback to telefono;
        else
          begin
            select count(*)
              into v_cantidad
              from ba_telefonos
             where cod_persona = p_cod_persona
               and principal = 'S';
            if v_cantidad > 1 then
              rollback to telefono;
            end if;
          exception
            when others then
              null;
          end;
        end if;
      else
        --Si no existe inserta el nuevo nro de telefono como principal
        v_retorno := fu_ins_tel_persona(p_cod_persona, p_telefono);
        if nvl(v_retorno, 'X') != 'S' then
          p_cod_error := 99;
          p_mensaje   := v_retorno;
          rollback to telefono;
        end if;
      end if;
    end if;
    if p_direccion is not null and p_cod_pais_res is not null and
       p_cod_ciudad is not null then
      v_existe  := null;
      v_retorno := null;
      begin
        select 'S'
          into v_existe
          from ba_direcciones t
         where t.direccion = p_direccion
           and t.cod_pais = nvl(p_cod_pais_res,v_cod_pais_res)
           and t.cod_ciudad = p_cod_ciudad
           and t.cod_persona = p_cod_persona;
      exception
        when no_data_found then
          v_existe := 'N';
        when too_many_rows then
          v_existe := 'S';
        when others then
          p_cod_error := 3;
          p_mensaje   := substr('Error al recuperar direcciones de la persona ' ||
                                p_cod_persona || ' Direccion: ' ||
                                p_direccion || ' Pais: ' || p_cod_pais_res ||
                                ' Ciudad: ' || p_cod_ciudad || ' - ' ||
                                sqlerrm,
                                1,
                                4000);
      end;

      savepoint direccion;
      v_cantidad := 0;
      --se deja todos los nros como no principal
      update ba_direcciones
         set principal = 'N'
       where cod_persona = p_cod_persona
         and principal = 'S';
      if nvl(v_existe, 'N') = 'S' then
        ---buscamos registro de Tipo P = Personal
         begin
           select 'S'
          into v_existe_dir
          from ba_direcciones t
         where t.direccion = p_direccion
           and t.cod_pais = nvl(p_cod_pais_res,v_cod_pais_res)
           and t.cod_ciudad = p_cod_ciudad
           and t.cod_persona = p_cod_persona
           and t.tipo='P';
        exception
          when no_data_found then
            v_existe_dir := 'N';
          when too_many_rows then
            v_existe_dir := 'S';
         end;

      if v_existe_dir='S' then
       -- actualiza el registro Tipo Personal como principal
       update ba_direcciones d
         set principal = 'S', tipo = 'P'
       where direccion = p_direccion
         and cod_pais = nvl(p_cod_pais_res,v_cod_pais_res)
         and cod_ciudad = p_cod_ciudad
         and cod_persona = p_cod_persona
         and tipo='P'
         and rownum = 1;
      else
        --se actualiza la direccion como principal
        update ba_direcciones d
           set principal = 'S', tipo = 'P'
         where direccion = p_direccion
           and cod_pais = nvl(p_cod_pais_res,v_cod_pais_res)
           and cod_ciudad = p_cod_ciudad
           and cod_persona = p_cod_persona
           and rownum = 1;
       end if;
        if sql%rowcount = 0 then
          p_cod_error := 99;
          p_mensaje   := 'No se pudo actualizar la direccion ' ||
                         p_direccion || ' como principal';
          rollback to direccion;
        else
          begin
            select count(*)
              into v_cantidad
              from ba_direcciones
             where cod_persona = p_cod_persona
               and principal = 'S';
            if v_cantidad > 1 then
              rollback to direccion;
            end if;
          exception
            when others then
              null;
          end;
        end if;
      else
        --Si no existe inserta la nueva direccion como principal
        v_retorno := fu_ins_dir_onb_persona(p_cod_persona,
                                            p_cod_pais_res,
                                            p_cod_ciudad,
                                            p_direccion,
                                            p_nro_casa,
                                            p_cal_secundaria,
                                            p_cod_barrio,
                                            p_cod_departamento,
                                            p_piso,
                                            p_edificio,
                                            p_referencias,
                                            p_latitud,
                                            p_longitud);
        if nvl(v_retorno, 'X') != 'S' then
          p_cod_error := 99;
          p_mensaje   := v_retorno;
          rollback to direccion;
        end if;
      end if; --direccion
    end if;
    if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
       nvl(p_cod_error, 0) != 0 then
      prg_ins_log_programas('PAG_PLA.PR_ACT_DAT_PERSONA',
                            substr('Error en la actualizacion de datos: ' ||
                                   p_mensaje,
                                   1,
                                   4000),
                            p_cod_persona,
                            null);
    end if;
  exception
    when others then
      p_mensaje   := substr(DBMS_UTILITY.format_error_stack || ' - ' ||
                            DBMS_UTILITY.format_error_backtrace ||
                            ' Cod.Persona: ' || p_cod_persona ||
                            ' Direccion: ' || p_direccion || ' Pais: ' ||
                            p_cod_pais_res || ' Ciudad: ' || p_cod_ciudad ||
                            'Correo: ' || p_correo || ' Telefono: ' ||
                            p_telefono || ' Profesion: ' || p_profesion,
                            1,
                            4000);
      p_cod_error := 4;
      if nvl(fug_obt_pardinamico('REG_LOG_PROGRAMAS'), 'S') = 'S' and
         nvl(p_cod_error, 0) != 0 then
        prg_ins_log_programas('PAG_PLA.PR_ACT_DAT_PERSONA',
                              substr(p_mensaje, 1, 4000),
                              p_cod_persona,
                              null);
      end if;
  end pr_act_dat_onb_persona;




END pag_pla;
/
