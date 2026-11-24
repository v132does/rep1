CREATE OR REPLACE PROCEDURE IT.PRT_SOL_WEB (P_COD_CANAL          IN GE_CANALES.COD_CANAL%TYPE,
                                         P_TIP_DOC_PRINCIPAL  IN BA_TIP_DOCUMENTOS.ABREVIATURA%TYPE,
                                         P_NRO_DOC_PRINCIPAL  IN BA_PERSONAS.NRO_DOCUMENTO%TYPE,
                                         P_NRO_CUENTA         IN TA_TARJETAS.NRO_CUENTA%TYPE,
                                         P_TIP_DOC_ADICIONAL  IN BA_TIP_DOCUMENTOS.ABREVIATURA%TYPE DEFAULT NULL,
                                         P_PAI_DOC_ADICIONAL  IN BA_PAISES.COD_PAIS%TYPE DEFAULT NULL,
                                         P_NRO_DOC_ADICIONAL  IN BA_PERSONAS.NRO_DOCUMENTO%TYPE DEFAULT NULL,
                                         P_PRI_NOM_ADICIONAL  IN BA_PER_FISICAS.PRI_NOMBRE%TYPE DEFAULT NULL,
                                         P_SEG_NOM_ADICIONAL  IN BA_PER_FISICAS.SEG_NOMBRE%TYPE DEFAULT NULL,
                                         P_PRI_APE_ADICIONAL  IN BA_PER_FISICAS.PRI_APELLIDO%TYPE DEFAULT NULL,
                                         P_SEG_APE_ADICIONAL  IN BA_PER_FISICAS.SEG_APELLIDO%TYPE DEFAULT NULL,
                                         P_COD_SEX_ADICIONAL  IN BA_PER_FISICAS.COD_SEXO%TYPE DEFAULT NULL,
                                         P_FEC_NAC_ADICIONAL  IN BA_PER_FISICAS.FEC_NACIMIENTO%TYPE DEFAULT NULL,
                                         P_EST_CIV_ADICIONAL  IN BA_PER_FISICAS.EST_CIVIL%TYPE DEFAULT NULL,
                                         P_NOM_EMB_ADICIONAL  IN TA_TARJETAS.NOM_EMBOZAR%TYPE DEFAULT NULL,
                                         P_DAT_ADJUNTOS       IN BW_ARCHIVOS.CONTENIDO%TYPE DEFAULT NULL,
                                         P_NOM_ADJUNTOS       IN BW_ARCHIVOS.NOMBRE%TYPE DEFAULT NULL,
                                         P_EST_PROCESO        OUT VARCHAR2,
                                         P_ID_SOLICITUD       OUT NUMBER,
                                         P_MENSAJE            OUT VARCHAR2) IS
   /**
    * P_TIP_SOLICITUD:
    * 1 => Aumento de Línea
    * 2 => Disminución de Línea
    * 3 => Solicitud de Adicionales
    */
   v_cod_per_adicional     ba_personas.cod_persona%TYPE;
   v_cod_per_principal     ba_personas.cod_persona%TYPE;
   v_codigo                ba_personas.cod_persona%TYPE;
   v_est_civil             ba_per_fisicas.est_civil%TYPE;
   v_cod_tip_documento     ba_tip_documentos.cod_tip_documento%TYPE;
   v_cod_tip_doc_principal ba_tip_documentos.cod_tip_documento%TYPE;
   v_nro_documento         ba_personas.nro_documento%TYPE;
   v_nro_comprobante       ta_sol_adicionales.nro_com_web%TYPE;
   v_nom_archivo           VARCHAR2(1000);
   v_men_fatca             VARCHAR2(200);
   v_cod_pais              ba_paises.cod_pais%TYPE;
   v_verificacion          VARCHAR2(1) := 'N';
   v_exi_vinculo           VARCHAR2(1) := 'E';
   v_crm_mail              ba_mails.dir_correo%TYPE := fug_obt_pardinamico('CAM_MAR_DIR_CRM');--'crm_solicitudprod@bbva.com.py';
   v_asunto                VARCHAR2(200);
   v_conn                  utl_smtp.connection;
   v_texto                 VARCHAR2(4000);

   -- Busca si ya existe la persona o cliente
   FUNCTION LF_OBT_PERSONAS (p_nro_documento     VARCHAR2,
                             p_cod_tip_documento VARCHAR2,
                             p_pri_nombre        VARCHAR2,
                             p_pri_apellido      VARCHAR2,
                             p_seg_nombre        VARCHAR2,
                             p_seg_apellido      VARCHAR2,
                             p_sexo              VARCHAR2,
                             p_fec_nacimiento    DATE    ) RETURN VARCHAR2 IS
      V_RETURN    VARCHAR2(1) := 'I';
      v_nro_documento ba_personas.nro_documento%TYPE;
   BEGIN
      /*
      Los valores posibles para la variable V_RETURN SON:
        P: Indica que existe persona exactamente parecida y se puede procesar la consulta.-
        A: Indica que existe persona parecida pero con alguna diferencia con los ingresado por el UF.-
        I: No existe la persona es necesario dar de alta en la Base.-
        E: Error
      */
      -- PASO_1: Buscar por Tipo y Número de documento
      BEGIN
         SELECT cod_persona
           INTO v_codigo
           FROM ba_personas
          WHERE nro_documento     = p_nro_documento
            AND cod_tip_documento = p_cod_tip_documento;
         V_RETURN := 'P'; -- Irá al PASO_3 a verificar que los nombres coincidan.-
      EXCEPTION
         WHEN no_data_found THEN
              V_RETURN   := 'I'; -- Irá al PASO_2 a buscar solo por el número de documento
              P_MENSAJE  := 'Persona Inexistente, se dará de alta en el CORE';
         WHEN OTHERS THEN
              V_RETURN      := 'E';
              P_EST_PROCESO := '003';
              P_MENSAJE     := 'Error buscando Persona por Tipo y Nro. de Documento '||sqlerrm;
      END;

      -- PASO_2: Buscar persona existente por número de documento
      IF V_RETURN = 'I' THEN
          BEGIN
             SELECT cod_persona
               INTO v_codigo
               FROM ba_personas
              WHERE nro_documento = p_nro_documento;
              V_RETURN  := 'A';
              P_MENSAJE := 'El Número de documento ya existe, pero el tipo es distinto';
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  V_RETURN   := 'I'; -- Irá al PASO_2 a buscar solo por el número de documento
                  P_MENSAJE  := 'Persona Inexistente, se dará de alta en el CORE';
             WHEN OTHERS THEN
                  V_RETURN      := 'E';
                  P_EST_PROCESO := '003';
                  P_MENSAJE     := 'Error buscando Persona por Nro. de Documento '||sqlerrm;
          END;
      END IF;
      -- PASO_3: Si existe por número de documento verifica que los nombres coincidan.-
      IF V_RETURN in ('P') THEN
         BEGIN
            -- Verificar que coincidan por el nombre completo.-
            SELECT 'P'
              INTO V_RETURN
              FROM ba_per_fisicas
             WHERE upper(ltrim(rtrim(nvl(pri_nombre  ,'X')))) = upper(ltrim(rtrim(nvl(p_pri_nombre  ,'X'))))
               AND upper(ltrim(rtrim(nvl(seg_nombre  ,'X')))) = upper(ltrim(rtrim(nvl(p_seg_nombre  ,'X'))))
               AND upper(ltrim(rtrim(nvl(pri_apellido,'X')))) = upper(ltrim(rtrim(nvl(p_pri_apellido,'X'))))
               AND upper(ltrim(rtrim(nvl(pri_apellido,'X')))) = upper(ltrim(rtrim(nvl(p_seg_apellido,'X'))))
               AND cod_persona                                = v_codigo;
         EXCEPTION
            WHEN no_data_found THEN
                 Begin
                      SELECT 'P'
                        INTO V_RETURN
                        FROM ba_per_fisicas
                       WHERE upper(ltrim(rtrim(nvl(pri_nombre  ,'X')))) = upper(ltrim(rtrim(nvl(p_pri_nombre  ,'X'))))
                         AND upper(ltrim(rtrim(nvl(pri_apellido,'X')))) = upper(ltrim(rtrim(nvl(p_pri_apellido,'X'))))
                         AND cod_persona                                = v_codigo;
                 Exception
                      When no_data_found Then
                           V_RETURN   := 'A';
                           P_MENSAJE  := 'Documento existente con Nombres distintos';
                      When Others Then
                           V_RETURN      := 'E';
                           P_EST_PROCESO := '003';
                           P_MENSAJE     := 'Error al buscar persona parecida por nombre corto'||p_nro_documento||' '||SQLERRM;
                 End;
            WHEN OTHERS THEN
                 V_RETURN      := 'E';
                 P_EST_PROCESO := '003';
                 P_MENSAJE     := 'Error al buscar persona parecida por nombre completo'||p_nro_documento||' '||SQLERRM;
         END;
      ELSIF V_RETURN in ('I') THEN
         -- Buscar Persona Física Existente por nombre.-
         If p_cod_tip_documento = 1 Then
             BEGIN
                SELECT p.nro_documento
                  INTO v_nro_documento
                  FROM ba_personas p, ba_per_fisicas pf
                 WHERE p.cod_persona                                = pf.cod_persona
                   AND upper(ltrim(rtrim(pri_nombre)))              = upper(ltrim(rtrim(p_pri_nombre)))
                   AND upper(ltrim(rtrim(pri_apellido)))            = upper(ltrim(rtrim(p_pri_apellido)))
                   AND upper(ltrim(rtrim(nvl(seg_nombre  , 'XX')))) = upper(ltrim(rtrim(nvl(p_seg_nombre  , 'XX'))))
                   AND upper(ltrim(rtrim(nvl(seg_apellido, 'XX')))) = upper(ltrim(rtrim(nvl(p_seg_apellido, 'XX'))))
                   AND nvl(fec_nacimiento, SYSDATE)                 = nvl(p_fec_nacimiento, SYSDATE)
                   AND cod_sexo                                     = nvl(p_sexo, 'X')
                   AND rownum                                       = 1;
             EXCEPTION
                WHEN no_data_found THEN
                     V_RETURN   := 'I';
                     P_MENSAJE  := 'Persona Inexistente, se dará de alta en el CORE';
                WHEN OTHERS THEN
                     V_RETURN      := 'E';
                     P_EST_PROCESO := '003';
                     P_MENSAJE     := 'Error al buscar Personas Físicas Parecidas: '||p_nro_documento||' '||SQLERRM;
             END;
         Else
             BEGIN
                SELECT p.nro_documento
                  INTO v_nro_documento
                  FROM ba_personas p, ba_per_juridicas pj
                 WHERE p.cod_persona                                = pj.cod_persona
                   AND (upper(ltrim(rtrim(pj.raz_social)))          = upper(ltrim(rtrim(p_pri_nombre)))
                        OR upper(ltrim(rtrim(pj.nom_comercial)))    = upper(ltrim(rtrim(p_pri_nombre)))
                        OR upper(ltrim(rtrim(nvl(pj.raz_social   ,'XX')))) = upper(ltrim(rtrim(nvl(p_pri_apellido,'XX'))))
                        OR upper(ltrim(rtrim(nvl(pj.nom_comercial,'XX')))) = upper(ltrim(rtrim(nvl(p_pri_apellido,'XX')))))
                   AND nvl(pj.fec_apertura, SYSDATE)                = nvl(p_fec_nacimiento, SYSDATE)
                   AND rownum                                       = 1;
             EXCEPTION
                WHEN NO_DATA_FOUND THEN
                     V_RETURN   := 'I';
                     P_MENSAJE  := 'Persona Inexistente, se dará de alta en el CORE';
                WHEN OTHERS THEN
                     V_RETURN      := 'E';
                     P_EST_PROCESO := '003';
                     P_MENSAJE     := 'Error al buscar Personas Jurídicas Parecidas: '||p_nro_documento||' '||SQLERRM;
             END;
         End If;
         IF V_NRO_DOCUMENTO IS NOT NULL THEN
            V_RETURN  := 'A';
            P_MENSAJE := 'Existen personas parecidas para '||p_pri_nombre||' '||p_pri_apellido||' verifique en el sistema el Documento Nro: '||v_nro_documento||' '||SQLERRM;
         END IF;

      END IF;

      RETURN V_RETURN;

   END;

   -- Funcion que retorna el codigo de persona desde el documento
   FUNCTION lf_obt_cod_persona (P_NRO_DOCUMENTO     VARCHAR2,
                                P_COD_TIP_DOCUMENTO VARCHAR2) RETURN VARCHAR2 IS
      v_codigo ba_personas.cod_persona%TYPE;
   BEGIN
      -- Busca la persona
      BEGIN
         SELECT cod_persona
           INTO v_codigo
           FROM ba_personas
          WHERE nro_documento     = p_nro_documento
            AND cod_tip_documento = p_cod_tip_documento;
      EXCEPTION
         WHEN no_data_found THEN
            v_codigo := NULL;
         WHEN OTHERS THEN
            P_EST_PROCESO := '002';
            P_MENSAJE     := 'Error al buscar la persona. Docuemento Nro= '||p_nro_documento||' '||SQLERRM;
      END;

      RETURN v_codigo;

   END;
   -- Funcion para obtener el mail del gestor
   FUNCTION lf_obt_mail(p_cod_persona ba_personas.cod_persona%TYPE) RETURN VARCHAR2 IS
     v_mail        ba_usuarios.dir_correo%TYPE;
     v_cod_oficial ge_clientes.cod_usu_oficial%TYPE;
   BEGIN 
     -- Buscamos al gestor del cliente
     BEGIN 
       SELECT a.cod_usu_oficial
         INTO v_cod_oficial
         FROM ge_clientes a
        WHERE a.cod_persona = p_cod_persona;
        -- Buscamos el mail del gestor
        v_mail := fug_obt_dir_mail_usu(v_cod_oficial);
        RETURN v_mail;
     EXCEPTION 
       WHEN no_data_found THEN 
         NULL;
       WHEN OTHERS THEN 
         P_EST_PROCESO := '014';
         P_MENSAJE     := 'Error al buscar mail del gestor '||SQLERRM;
     END;
     
   END;
/*   FUNCTION DEPURARTEXTOS(P_STRING  IN VARCHAR2,
                          MAXLENGTH IN NUMBER,
                          P_DOCUMENTO IN VARCHAR2 DEFAULT 'N') RETURN VARCHAR2 IS
   BEGIN
      IF p_documento = 'N' THEN --texto
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^0-9A-Za-z ,./_-])', ''), 1, maxLength);
      ELSE --documento
         RETURN SUBSTR(REGEXP_REPLACE(TRIM(p_string), '([^0-9A-Za-z-])', ''), 1, maxLength);
      END IF;
   END;*/
BEGIN -- INICIO PROCESO PRINCIPAL --
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
      P_EST_PROCESO := '000';
      BEGIN
         SELECT cod_tip_documento
           INTO v_cod_tip_doc_principal
           FROM ba_tip_documentos
          WHERE abreviatura = P_TIP_DOC_PRINCIPAL;
      EXCEPTION
         WHEN no_data_found THEN
            P_EST_PROCESO := '001';
            P_MENSAJE     := 'Tipo de documento no registrado. Documento Nro= '||P_TIP_DOC_PRINCIPAL;
      END;
      If nvl(P_EST_PROCESO,'000') = '000' Then
          v_cod_per_principal  := lf_obt_cod_persona(P_NRO_DOC_PRINCIPAL, V_COD_TIP_DOC_PRINCIPAL);
          If nvl(P_EST_PROCESO,'000') = '000' Then
              BEGIN
                 SELECT cod_tip_documento
                   INTO v_cod_tip_documento
                   FROM ba_tip_documentos
                  WHERE abreviatura = P_TIP_DOC_ADICIONAL;
              EXCEPTION
                 WHEN no_data_found THEN
                    P_EST_PROCESO := '001';
                    P_MENSAJE     := 'Tipo de documento no registrado. Documento Nro= '||P_NRO_DOC_ADICIONAL;
              END;
              v_cod_per_adicional  := lf_obt_cod_persona(P_NRO_DOC_ADICIONAL, V_COD_TIP_DOCUMENTO);
              If nvl(P_EST_PROCESO,'000') = '000' Then
                  v_verificacion       := lf_obt_personas(P_NRO_DOC_ADICIONAL,
                                                          V_COD_TIP_DOCUMENTO,
                                                          P_PRI_NOM_ADICIONAL,
                                                          P_PRI_APE_ADICIONAL,
                                                          P_SEG_NOM_ADICIONAL,
                                                          P_SEG_APE_ADICIONAL,
                                                          P_COD_SEX_ADICIONAL,
                                                          P_FEC_NAC_ADICIONAL);
                  IF v_verificacion in ('I') THEN -- No existe el Adicional, es necesario insertar

                        v_nro_documento := P_NRO_DOC_ADICIONAL;

                        SELECT s_cod_persona.nextval
                          INTO v_cod_per_adicional
                          FROM dual;

                        begin
                            select a.cod_pais
                              into v_cod_pais
                              from ba_paises a
                             where a.cod_pais = P_PAI_DOC_ADICIONAL;
                        exception
                          when no_data_found then
                               P_EST_PROCESO := '004';
                               P_MENSAJE     := 'Error al buscar Pais. Id: '||P_PAI_DOC_ADICIONAL||' '||SQLERRM;
                        end;
                        If nvl(P_EST_PROCESO,'000') = '000' Then
                            BEGIN
                               INSERT INTO ba_personas (cod_persona        ,
                                                        nom_completo       ,
                                                        tipo               ,
                                                        cod_tip_documento  ,
                                                        nro_documento      ,
                                                        cod_pais           ,
                                                        cod_actividad      ,
                                                        est_verificacion   ,
                                                        obs_verificacion   )
                                                VALUES (v_cod_per_adicional,
                                                        P_PRI_NOM_ADICIONAL||' '||P_SEG_NOM_ADICIONAL||' '||P_PRI_APE_ADICIONAL||' '||P_SEG_APE_ADICIONAL,
                                                        decode(P_TIP_DOC_ADICIONAL,'RUC','J','F'),
                                                        v_cod_tip_documento,
                                                        P_NRO_DOC_ADICIONAL,
                                                        v_cod_pais         ,
                                                        '701'                ,
                                                        'N'                ,
                                                        'SOLICITUDES DESDE LA WEB');
                            EXCEPTION
                               WHEN OTHERS THEN
                                  v_verificacion := 'E';
                                  P_EST_PROCESO  := '005';
                                  P_MENSAJE      := 'Error al insertar datos en BA_PERSONAS. Documento Nro= '||P_NRO_DOC_ADICIONAL||' '||SQLERRM;
                            END;

                            IF P_EST_CIV_ADICIONAL IS NOT NULL AND nvl(P_EST_PROCESO,'000') = '000' THEN
                               -- ba_per_fisicas
                               BEGIN
                                  SELECT val_minimo
                                    INTO v_est_civil
                                    FROM ba_cod_referencias
                                   WHERE dominio    = 'COD_EST_CIVIL'
                                     AND val_minimo = P_EST_CIV_ADICIONAL;
                               EXCEPTION
                                  WHEN no_data_found THEN
                                     v_verificacion := 'E';
                                     P_EST_PROCESO  := '006';
                                     P_MENSAJE      := 'No existe estado civil definido. Documento Nro= '||P_NRO_DOC_ADICIONAL||' - '||SQLERRM;
                                  WHEN OTHERS THEN
                                     v_verificacion := 'E';
                                     P_EST_PROCESO  := '007';
                                     P_MENSAJE      := 'Error al buscar el Estado Civil Documento. Nro= '||P_NRO_DOC_ADICIONAL||' '||SQLERRM;
                               END;
                            ELSE
                               v_est_civil := 'S';
                            END IF;
                        
                            If P_TIP_DOC_ADICIONAL <> 'RUC' AND nvl(P_EST_PROCESO,'000') = '000' Then
                                BEGIN
                                   INSERT INTO ba_per_fisicas (cod_persona          ,
                                                               pri_nombre           ,
                                                               pri_apellido         ,
                                                               est_civil            ,
                                                               cod_sexo             ,
                                                               cod_pai_nacionalidad ,
                                                               seg_nombre           ,
                                                               seg_apellido         ,
                                                               fec_nacimiento       )
                                                        VALUES(v_cod_per_adicional  ,
                                                               P_PRI_NOM_ADICIONAL  ,
                                                               P_PRI_APE_ADICIONAL  ,
                                                               v_est_civil          ,
                                                               P_COD_SEX_ADICIONAL  ,
                                                               v_cod_pais           ,
                                                               P_SEG_NOM_ADICIONAL  ,
                                                               P_SEG_APE_ADICIONAL  ,
                                                               P_FEC_NAC_ADICIONAL  );
                                EXCEPTION
                                   WHEN OTHERS THEN
                                      v_verificacion := 'E';
                                      P_EST_PROCESO  := '008';
                                      P_MENSAJE      := 'Error al insertar datos en BA_PER_FISICAS. Documento Nro= '||P_NRO_DOC_ADICIONAL||' '||SQLERRM;
                                END;
                            Elsif P_TIP_DOC_ADICIONAL = 'RUC' AND nvl(P_EST_PROCESO,'000') = '000' Then
                                BEGIN
                                   INSERT INTO ba_per_juridicas (cod_persona          ,
                                                                 raz_social           ,
                                                                 nom_comercial        ,
                                                                 fec_apertura         )
                                                          VALUES(v_cod_per_adicional  ,
                                                                 P_PRI_NOM_ADICIONAL  ,
                                                                 P_PRI_NOM_ADICIONAL  ,
                                                                 P_FEC_NAC_ADICIONAL  );
                                EXCEPTION
                                   WHEN OTHERS THEN
                                      v_verificacion := 'E';
                                      P_EST_PROCESO  := '008';
                                      P_MENSAJE      := 'Error al insertar datos en BA_PER_JURIDICAS. Documento Nro= '||P_NRO_DOC_ADICIONAL||' '||SQLERRM;
                                END;
                            End If;
                        End If;
                        --FATCA
                        IF nvl(P_EST_PROCESO,'000') = '000' Then
                           PAE_FAT.PR_ACT_PER_FATCA(v_cod_per_adicional,'F',null,'S', v_men_fatca, 'S');
                        End If;
                  End If;
                  If nvl(P_EST_PROCESO,'000') = '000' Then
                     Begin
                        select S_NRO_COMPROBANTE.nextval
                          into P_ID_SOLICITUD --v_nro_comprobante
                          from dual;
                     Exception
                         When Others Then
                              P_EST_PROCESO  := '009';
                              P_MENSAJE      := 'Ocurrio un error al Obtener el Número de Comprobante Web'||sqlerrm;
                     End;
                     If nvl(P_EST_PROCESO,'000') = '000' Then
                         Begin
                           insert into ta_sol_adicionales (cod_persona        , 
                                                           cod_estado         ,
                                                           fec_ingreso        , 
                                                           nom_embozado       , 
                                                           cod_usu_autoriza   ,
                                                           cod_usu_promotor   , 
                                                           cod_usu_oficial    ,
                                                           cod_canal          , 
                                                           observacion        , 
                                                           nro_cuenta         ,
                                                           nro_com_web        )
                                                   values (v_cod_per_adicional, 
                                                           'PAN'              ,
                                                           sysdate            , 
                                                           P_NOM_EMB_ADICIONAL, 
                                                           null               ,
                                                           null               ,  
                                                           null               , 
                                                           P_COD_CANAL        ,
                                                           'Solicitud de TC Adicionales desde la Web',
                                                           P_NRO_CUENTA       ,
                                                           --v_nro_comprobante  );
                                                           P_ID_SOLICITUD     );
                         Exception
                           when others then
                                P_EST_PROCESO  := '010';
                                P_MENSAJE      := 'Ocurrio un error al insertar datos en TA_SOL_ADICIONALES Doc.Nro.'||P_NRO_DOC_ADICIONAL||' '||sqlerrm;
                         End; 
                         If nvl(P_EST_PROCESO,'000') = '000' Then
                             Begin
                              select 'E'
                                into v_exi_vinculo
                                from ba_vinculos g
                               where g.cod_per_vinculo = v_cod_per_adicional
                                 and g.cod_persona     = v_cod_per_principal;
                             Exception
                               when  no_data_found then
                                     insert into ba_vinculos (cod_persona        , 
                                                              cod_per_vinculo    , 
                                                              tipo               )
                                                      values (v_cod_per_principal, 
                                                              v_cod_per_adicional, 
                                                              'OT'               );
                               when others then
                                    P_EST_PROCESO  := '011';
                                    P_MENSAJE      :=  'Ocurrió un error al Verificar vinculo '||sqlerrm;
                             End;
                         End If;
                         If P_DAT_ADJUNTOS is not null and nvl(P_EST_PROCESO,'000') = '000' Then
                            IF paw_uti.fu_ins_archivo(v_cod_per_adicional,
                                                      '078', 
                                                      P_ID_SOLICITUD, 
                                                      P_DAT_ADJUNTOS, 
                                                      P_NOM_ADJUNTOS) < 0 THEN
                               P_EST_PROCESO  := '012';
                               P_MENSAJE      :=  'Ocurrió un error al Almacenar Adjuntos '||sqlerrm;
                            END IF;
                            IF nvl(P_EST_PROCESO,'000') = '000' THEN 
                               -- Enviar notificacion al gestor y supervisor
                               DECLARE
                                 v_cabecera VARCHAR2(4000);
                                 v_detalle  VARCHAR2(4000);
                                 --v_texto    VARCHAR2(4000);
                                 v_mail     ba_mails.dir_correo%TYPE;
                                 v_ret      NUMBER;
                               BEGIN
                                 -- Call the function
                                 v_cabecera := paw_pro.fu_not_titulo('Solicitud de Adicional');
                                 v_detalle  := 'El cliente ' ||fue_obt_nom_persona(v_cod_per_principal)|| ', solicita tarjeta adicional de su cuenta nro ' ||P_NRO_CUENTA||'. 
                                               <br>Verificar y finalizar su circuito.';
                                 v_texto    := v_cabecera||v_detalle;
                                 v_mail     := lf_obt_mail(v_cod_per_principal);
                                 v_ret      := paw_not.fu_env_email_prueba(v_mail,
                                                                           v_texto,
                                                                           'PRT_SOL_WEB');
                               EXCEPTION
                                 WHEN OTHERS THEN
                                   P_EST_PROCESO  := '013';
                                   P_MENSAJE      :=  'No se pudo enviar mail de notificacion al Gestor '||sqlerrm;
                               END;
                               -- invocamos a IT_MAIL para el envio de correo a CRM
                               BEGIN
                                 --3209747|20190520 114518;9;  => (CI|Fecha Hora ;*Producto; )*
                                 v_asunto   := p_nro_doc_principal||'|'||to_char(SYSDATE,'YYYYMMDD HHMMSS')||';9;';
                                 v_conn     := it_mail.begin_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                                                                  v_crm_mail,
                                                                  v_asunto,
                                                                  IT_MAIL.MULTIPART_MIME_TYPE);
                                 it_mail.attach_text(v_conn, v_texto, 'text/html');
                                 --it_mail.write_text(v_conn, v_texto_detalle);
                                 it_mail.end_mail(v_conn);
                               EXCEPTION
                                 WHEN OTHERS THEN
                                   --  No se pudo enviar mail a CRM '
                                   INSERT INTO tm_mails 
                                     (env_por, env_para, asunto, 
                                      detalles, fec_sistema, cod_usuario)
                                   VALUES 
                                     (fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'), v_crm_mail, 'Envio a CRM', 
                                      'Cliente: '||v_cod_per_principal||' Cuenta: '||p_nro_cuenta ||' - '||substr(v_asunto,1,3900), SYSDATE, USER)  ;
                               END;
                            END IF;
                         End If;
                     End If;
                 End If;
              End If;
          End If;
      End If;
EXCEPTION
   WHEN OTHERS THEN
        P_EST_PROCESO  := '099';
        P_MENSAJE      := ('Error '||v_nro_documento||'-'||SQLERRM);
END;
/

