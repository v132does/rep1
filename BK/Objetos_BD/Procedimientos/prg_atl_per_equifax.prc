CREATE OR REPLACE PROCEDURE IT.PRG_ATL_PER_EQUIFAX (P_TIP_EJECUCION IN VARCHAR2,
                                                 P_COD_PERSONA   IN BA_PERSONAS.COD_PERSONA%TYPE DEFAULT NULL) IS
   /*
   C => Consulta Masiva, esperando respuesta
   P => Consulta puntual, procesado satisfactoriamente
   E => Error
   A => Advertencia
   I => Incluir al Core
   */
   v_cod_entidad         varchar2(3) := fug_obt_pardinamico('NRO_CLI_EQUIFAX');
   v_cod_persona         ba_personas.cod_persona%TYPE;
   v_codigo              ba_personas.cod_persona%TYPE;
   v_est_civil           ba_per_fisicas.est_civil%TYPE;
   v_cod_tip_documento   ba_tip_documentos.cod_tip_documento%TYPE;
   v_nro_documento       ba_personas.nro_documento%TYPE;
   v_lugar               VARCHAR2(50);
   v_men_fatca           varchar2(200);
   v_cod_pais            ba_paises.cod_pais%type;
   v_error               varchar2(2000);
   v_verificacion        varchar2(1) := 'N';
   v_fec_actual          date := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_ult_fec_masiva      varchar2(3) := FUG_OBT_PARDINAMICO('EQU_CAN_DIA_VIG_MASIVA');
   v_ult_fec_individual  varchar2(3) := FUG_OBT_PARDINAMICO('EQU_CAN_DIA_VIG_INDIVIDUAL');
   v_xml                 varchar2(32767) := null;
   v_antiguedad          number := 0; --HO -CROBPEFX-124 -variable para control de dias de envio masivo
   -- Obtiene los clientes temporales.
   CURSOR DATOS IS
          Select a.*, rowid
          From ge_equ_consulta_tmp a
          --where decode(P_TIP_EJECUCION,'V','1',a.estado) = decode(P_TIP_EJECUCION,'V','1','P');
          where a.usu_insercion  = user
            and nvl(p_cod_persona,nvl(a.cod_persona,1))    = nvl(p_cod_persona, nvl(a.cod_persona,1))
            and (p_tip_ejecucion = 'V' or (p_tip_ejecucion = 'P' and a.estado <> 'E'));

   -- Almacenar los datos en formato XML
   FUNCTION LF_GEN_DAT_ENVIAR ( P_TIP_DOCUMENTO         IN VARCHAR2,
                                P_PAI_DOCUMENTO         IN VARCHAR2,
                                P_NRO_DOCUMENTO         IN VARCHAR2,
                                P_NACIONALIDAD          IN VARCHAR2,
                                P_APELLIDO1             IN VARCHAR2,
                                P_APELLIDO2             IN VARCHAR2,
                                P_APE_CASADA            IN VARCHAR2,
                                P_NOMBRE1               IN VARCHAR2,
                                P_NOMBRE2               IN VARCHAR2,
                                P_FEC_NACIMIENTO        IN DATE,
                                P_COD_SEXO              IN VARCHAR2,
                                P_EST_CIVIL             IN VARCHAR2,
                                P_CALLE                 IN VARCHAR2,
                                P_NRO_PUERTA            IN VARCHAR2,
                                P_APARTAMENTO           IN VARCHAR2,
                                P_PISO                  IN VARCHAR2,
                                P_COMPLEMENTO           IN VARCHAR2,
                                P_KILOMETRO             IN VARCHAR2,
                                P_MANZANA               IN VARCHAR2,
                                P_LOTE                  IN VARCHAR2,
                                P_BLOCK                 IN VARCHAR2,
                                P_ESQUINA1              IN VARCHAR2,
                                P_ESQUINA2              IN VARCHAR2,
                                P_PENSION_HOTEL         IN VARCHAR2,
                                P_PROP_INQUILINO        IN VARCHAR2,
                                P_ID_CIUDAD             IN VARCHAR2,
                                P_CIU_DISTRITO          IN VARCHAR2,
                                P_LOCAL_BARRIO          IN VARCHAR2,
                                P_DEPARTAMENTO          IN VARCHAR2,
                                P_COD_POSTAL            IN VARCHAR2,
                                P_TELEFONO              IN VARCHAR2,
                                P_EMPRESA               IN VARCHAR2,
                                P_OCUP_CARGO            IN VARCHAR2,
                                P_PROFESION             IN VARCHAR2,
                                P_CALLE_EMP             IN VARCHAR2,
                                P_NRO_PUERTA_EMP        IN VARCHAR2,
                                P_APARTAMENTO_EMP       IN VARCHAR2,
                                P_PISO_EMP              IN VARCHAR2,
                                P_COMPLEMENTO_EMP       IN VARCHAR2,
                                P_KILONETRO_RMP         IN VARCHAR2,
                                P_MANZANA_EMP           IN VARCHAR2,
                                P_LOTE_EMP              IN VARCHAR2,
                                P_BLOCK_EMP             IN VARCHAR2,
                                P_ESQUINA1_EMP          IN VARCHAR2,
                                P_ESQUINA2_EMP          IN VARCHAR2,
                                P_ID_CIUDAD_EMP         IN VARCHAR2,
                                P_CIUDAD_DISTRITO_EMP   IN VARCHAR2,
                                P_LOCALIDAD_BARRIO_EMP  IN VARCHAR2,
                                P_DEPARTAMENTO_EMP      IN VARCHAR2,
                                P_COD_POSTAL_EMP        IN VARCHAR2,
                                P_INGRESO_EMP           IN VARCHAR2,
                                P_TELEFONO_EMP          IN VARCHAR2,
                                P_TIPO_DOC_CONY         IN VARCHAR2,
                                P_PAIS_DOC_CONY         IN VARCHAR2,
                                P_DOCUMENTO_CONY        IN VARCHAR2,
                                P_NACIONALIDAD_CONY     IN VARCHAR2,
                                P_APELLIDO1_CONY        IN VARCHAR2,
                                P_APELLIDO2_CONY        IN VARCHAR2,
                                P_APE_CASADA_CONY       IN VARCHAR2,
                                P_NOMBRE1_CONY          IN VARCHAR2,
                                P_NOMBRE2_CONY          IN VARCHAR2,
                                P_MOTIVO                IN VARCHAR2,
                                P_TIP_DEUDOR            IN VARCHAR2,
                                P_DAT_EXTRAS            IN VARCHAR2) RETURN VARCHAR2 IS
          v_return  varchar2(32767) := null;

       BEGIN --'<?xml version="1.0" encoding="ISO-8859-1" ?>'||
            v_return :=(
                        '<Experto>'||'<Datos>'   ||
                        '<integrante>'           || 1                    ||'</integrante>'            ||
                        '<fecha_datos>'          ||to_char(V_FEC_ACTUAL,'DDMMYYYY')||'</fecha_datos>'||
                        '<tipo_doc>'             ||P_TIP_DOCUMENTO       ||'</tipo_doc>'              ||
                        '<pais_doc>'             ||P_PAI_DOCUMENTO       ||'</pais_doc>'              ||
                        '<documento>'            ||P_NRO_DOCUMENTO       ||'</documento>'             ||
                        '<nacionalidad>'         ||P_NACIONALIDAD        ||'</nacionalidad>'          ||
                        '<apellido1>'            ||P_APELLIDO1           ||'</apellido1>'             ||
                        '<apellido2>'            ||P_APELLIDO2           ||'</apellido2>'             ||
                        '<apellido_casada>'      ||P_APE_CASADA          ||'</apellido_casada>'       ||
                        '<nombre1>'              ||P_NOMBRE1             ||'</nombre1>'               ||
                        '<nombre2>'              ||P_NOMBRE2             ||'</nombre2>'               ||
                        '<nacimiento>'           ||TO_CHAR(P_FEC_NACIMIENTO,'DDMMYYYY')||'</nacimiento>'||
                        '<sexo>'                 ||P_COD_SEXO            ||'</sexo>'                  ||
                        '<est_civil>'            ||P_EST_CIVIL           ||'</est_civil>'             ||
                        '<calle>'                ||P_CALLE               ||'</calle>'                 ||
                        '<nro_puerta>'           ||P_NRO_PUERTA          ||'</nro_puerta>'            ||
                        '<apartamento>'          ||P_APARTAMENTO         ||'</apartamento>'           ||
                        '<piso>'                 ||P_PISO                ||'</piso>'                  ||
                        '<complemento>'          ||P_COMPLEMENTO         ||'</complemento>'           ||
                        '<kilometro>'            ||P_KILOMETRO           ||'</kilometro>'             ||
                        '<manzana>'              ||P_MANZANA             ||'</manzana>'               ||
                        '<lote>'                 ||P_LOTE                ||'</lote>'                  ||
                        '<block>'                ||P_BLOCK               ||'</block>'                 ||
                        '<esquina1>'             ||P_ESQUINA1            ||'</esquina1>'              ||
                        '<esquina2>'             ||P_ESQUINA2            ||'</esquina2>'              ||
                        '<pension_hotel>'        ||P_PENSION_HOTEL       ||'</pension_hotel>'         ||
                        '<prop_inquilino>'       ||P_PROP_INQUILINO      ||'</prop_inquilino>'        ||
                        '<id_ciudad>'            ||P_ID_CIUDAD           ||'</id_ciudad>'             ||
                        '<ciudad_distrito>'      ||P_CIU_DISTRITO        ||'</ciudad_distrito>'       ||
                        '<localidad_barrio>'     ||P_LOCAL_BARRIO        ||'</localidad_barrio>'      ||
                        '<departamento>'         ||P_DEPARTAMENTO        ||'</departamento>'          ||
                        '<cod_postal>'           ||P_COD_POSTAL          ||'</cod_postal>'            ||
                        '<telefono>'             ||P_TELEFONO            ||'</telefono>'              ||
                        '<emp_empleo>'           ||P_EMPRESA             ||'</emp_empleo>'            ||
                        '<ocup_cargo>'           ||P_OCUP_CARGO          ||'</ocup_cargo>'            ||
                        '<profesion>'            ||P_PROFESION           ||'</profesion>'             ||
                        '<calle_emp>'            ||P_CALLE_EMP           ||'</calle_emp>'             ||
                        '<nro_puerta_emp>'       ||P_NRO_PUERTA_EMP      ||'</nro_puerta_emp>'        ||
                        '<apartamento_emp>'      ||P_APARTAMENTO_EMP     ||'</apartamento_emp>'       ||
                        '<piso_emp>'             ||P_PISO_EMP            ||'</piso_emp>'              ||
                        '<complemento_emp>'      ||P_COMPLEMENTO_EMP     ||'</complemento_emp>'       ||
                        '<kilometro_emp>'        ||P_KILONETRO_RMP       ||'</kilometro_emp>'         ||
                        '<manzana_emp>'          ||P_MANZANA_EMP         ||'</manzana_emp>'           ||
                        '<lote_emp>'             ||P_LOTE_EMP            ||'</lote_emp>'              ||
                        '<block_emp>'            ||P_BLOCK_EMP           ||'</block_emp>'             ||
                        '<esquina1_emp>'         ||P_ESQUINA1_EMP        ||'</esquina1_emp>'          ||
                        '<esquina2_emp>'         ||P_ESQUINA2_EMP        ||'</esquina2_emp>'          ||
                        '<id_ciudad_emp>'        ||P_ID_CIUDAD_EMP       ||'</id_ciudad_emp>'         ||
                        '<ciudad_distrito_emp>'  ||P_CIUDAD_DISTRITO_EMP ||'</ciudad_distrito_emp>'   ||
                        '<localidad_barrio_emp>' ||P_LOCALIDAD_BARRIO_EMP||'</localidad_barrio_emp>'  ||
                        '<departamento_emp>'     ||P_DEPARTAMENTO_EMP     ||'</departamento_emp>'      ||
                        '<cod_postal_emp>'       ||P_COD_POSTAL_EMP      ||'</cod_postal_emp>'        ||
                        '<ingreso_emp>'          ||P_INGRESO_EMP         ||'</ingreso_emp>'           ||
                        '<telefono_emp>'         ||P_TELEFONO_EMP        ||'</telefono_emp>'          ||
                        '<tipo_doc_cony>'        ||P_TIPO_DOC_CONY       ||'</tipo_doc_cony>'         ||
                        '<pais_doc_cony>'        ||P_PAIS_DOC_CONY       ||'</pais_doc_cony>'         ||
                        '<documento_cony>'       ||P_DOCUMENTO_CONY      ||'</documento_cony>'        ||
                        '<nacionalidad_cony>'    ||P_NACIONALIDAD_CONY   ||'</nacionalidad_cony>'     ||
                        '<apellido1_cony>'       ||P_APELLIDO1_CONY      ||'</apellido1_cony>'        ||
                        '<apellido2_cony>'       ||P_APELLIDO2_CONY      ||'</apellido2_cony>'        ||
                        '<apellido_casada_cony>' ||P_APE_CASADA_CONY     ||'</apellido_casada_cony>'  ||
                        '<nombre1_cony>'         ||P_NOMBRE1_CONY        ||'</nombre1_cony>'          ||
                        '<nombre2_cony>'         ||P_NOMBRE2_CONY        ||'</nombre2_cony>'          ||
                        '<motivo_consulta>'      ||P_MOTIVO              ||'</motivo_consulta>'       ||
                        '<operacion>'            ||P_TIP_DEUDOR          ||'</operacion>'             ||
                        '<Datos_Extras>'         ||P_DAT_EXTRAS          ||'</Datos_Extras>'          ||
                        '</Datos>'||'</Experto>');
            return v_return;
       END;

   -- Busca si ya existe la persona o cliente
   FUNCTION LF_OBT_PERSONAS (p_nro_documento     VARCHAR2,
                             p_cod_tip_documento VARCHAR2,
                             p_pri_nombre        VARCHAR2,
                             p_pri_apellido      VARCHAR2,
                             p_seg_nombre        VARCHAR2,
                             p_seg_apellido      VARCHAR2,
                             p_sexo              VARCHAR2,
                             p_fec_nacimiento    DATE    ,
                             p_tip_consulta      varchar2) RETURN VARCHAR2 IS
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
              V_RETURN := 'I'; -- Irá al PASO_2 a buscar solo por el número de documento
              V_ERROR  := 'Persona Inexistente, se dará de alta en el CORE';
         WHEN OTHERS THEN
              V_RETURN := 'E';
              V_ERROR  := 'Error buscando Persona por Tipo y Nro. de Documento '||sqlerrm;
      END;

      -- PASO_2: Buscar persona existente por número de documento
      IF V_RETURN = 'I' THEN
          BEGIN
             SELECT cod_persona
               INTO v_codigo
               FROM ba_personas
              WHERE nro_documento = p_nro_documento;
              V_RETURN := 'A';
              V_ERROR  := 'El Número de documento ya existe, pero el tipo es distinto';
          EXCEPTION
             WHEN NO_DATA_FOUND THEN
                  V_RETURN := 'I'; -- Irá al PASO_2 a buscar solo por el número de documento
                  V_ERROR  := 'Persona Inexistente, se dará de alta en el CORE';
             WHEN OTHERS THEN
                  V_RETURN := 'E';
                  V_ERROR  := 'Error buscando Persona por Nro. de Documento '||sqlerrm;
          END;
      END IF;
      If V_RETURN in ('P') THEN
         select antiguedad into v_antiguedad from GE_EQU_CONSULTA_TMP where nro_documento = p_nro_documento; --HO -CROBPEFX-124 -se obtiene valor de antiguedad por nro de documento
         if v_antiguedad is null then
           Begin
               Select distinct('A'), 'Persona recientemente consultada: '||to_char(a.fecha,'DD/MM/YYYY')||' ¿Volver a Consultar?'
                 into V_RETURN     , V_ERROR
                 from ge_equ_consultas_cab a
                where a.cod_persona = v_codigo
                  and a.fecha = (select max(b.fecha)
                                from ge_equ_consultas_cab b
                               where b.cod_persona = a.cod_persona)
                  and (v_fec_actual - a.fecha) <= decode(p_tip_consulta,1,v_ult_fec_masiva,v_ult_fec_individual);
           Exception
                When no_data_found Then
                     V_RETURN := 'P';
                     V_ERROR  := null;
                When Others Then
                     V_RETURN := 'E';
                     V_ERROR  := 'Error Buscando Ultima Fecha de Consulta '||sqlerrm;
           End;
         elsif v_antiguedad is not null then
          Begin
            --HO -CROBPEFX-124 -si el campo antiguedad no es nulo, es porque viene de una importacion masiva y se controla la antiguedad de otra manera
            Select distinct('E'), 'No cumple con antiguedad minima requerida para volver a enviar, persona '||v_codigo
              into V_RETURN     , V_ERROR
              from ge_equ_consultas_cab a
             where a.cod_persona = v_codigo
               and a.fecha = (select max(b.fecha)
                                from ge_equ_consultas_cab b
                               where b.cod_persona = a.cod_persona)
               and (v_fec_actual - a.fecha) >= v_antiguedad;
          Exception
            When no_data_found Then
                V_RETURN := 'P';
                V_ERROR  := null;
            When Others Then
                V_RETURN := 'E';
                V_ERROR  := 'Error verificando Antiguedad de Consulta '||sqlerrm;
           End;
         end if;
      End If;
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
                           V_RETURN := 'A';
                           V_ERROR      := 'Documento existente con Nombres distintos';
                      When Others Then
                           V_RETURN := 'E';
                           V_ERROR  := 'Error al buscar persona parecida por nombre corto'||p_nro_documento||' '||SQLERRM;
                 End;
            WHEN OTHERS THEN
                 V_RETURN := 'E';
                 V_ERROR  := 'Error al buscar persona parecida por nombre completo'||p_nro_documento||' '||SQLERRM;
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
                     V_RETURN := 'I';
                     V_ERROR  := 'Persona Inexistente, se dará de alta en el CORE';
                WHEN OTHERS THEN
                     V_RETURN := 'E';
                     V_ERROR  := 'Error al buscar Personas Físicas Parecidas: '||p_nro_documento||' '||SQLERRM;
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
                     V_RETURN := 'I';
                     V_ERROR  := 'Persona Inexistente, se dará de alta en el CORE';
                WHEN OTHERS THEN
                     V_RETURN := 'E';
                     V_ERROR  := 'Error al buscar Personas Jurídicas Parecidas: '||p_nro_documento||' '||SQLERRM;
             END;
         End If;
         IF V_NRO_DOCUMENTO IS NOT NULL THEN
            V_RETURN := 'A';
            V_ERROR  := 'Existen personas parecidas para '||p_pri_nombre||' '||p_pri_apellido||' verifique en el sistema el Documento Nro: '||v_nro_documento||' '||SQLERRM;
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
            v_error := 'Error al buscar la persona. Docuemento Nro= '||p_nro_documento||' '||SQLERRM;
      END;

      RETURN v_codigo;

   END;

   -- Procedimiento que marca con error el registro
   PROCEDURE PF_MARCAR_ERROR (P_ERROR IN VARCHAR2,
                              P_ROWID IN ROWID) IS

    BEGIN
        update ge_equ_consulta_tmp a
           set a.estado      = 'E',
               a.error       = P_ERROR,
               a.cod_cliente = v_cod_entidad
         where a.rowid       = P_ROWID;
    EXCEPTION
        when others then
             raise_application_error(-20000,'Error Actualizando Tipo de documento no registrado '||sqlerrm);
    END;
BEGIN -- INICIO PROCESO PRINCIPAL --
   BEGIN pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; END;
   FOR t IN DATOS LOOP
      v_lugar := '0-Tipo de Documento';
      BEGIN
         SELECT cod_tip_documento
           INTO v_cod_tip_documento
           FROM ba_tip_documentos
          WHERE abreviatura = t.tip_documento;
      EXCEPTION
         WHEN no_data_found THEN
            v_cod_tip_documento := null;
            v_error             := 'Tipo de documento no registrado. Documento Nro= '||t.Nro_Documento;
            PF_MARCAR_ERROR(V_ERROR,T.ROWID);
      END;

      If v_cod_tip_documento is not null Then
          v_cod_persona  := lf_obt_cod_persona(t.Nro_Documento, v_cod_tip_documento);
          v_lugar        := '1-Datos Persona';
          v_verificacion := lf_obt_personas(t.Nro_Documento    ,
                                            v_cod_tip_documento,
                                            t.Nombre1          ,
                                            t.Apellido1        ,
                                            t.Nombre2          ,
                                            t.Apellido2        ,
                                            t.cod_sexo         ,
                                            t.fec_nacimiento   ,
                                            t.tip_consulta     );
          If T.TIP_CONSULTA = 2 Then -- Consulta Puntual, va por WS
              --(N): No Requerido
              --(S): Requerido
              v_xml := LF_GEN_DAT_ENVIAR (T.TIP_DOCUMENTO        ,--(N)
                                          T.PAI_DOCUMENTO        ,--(N)
                                          T.NRO_DOCUMENTO        ,--(N)
                                          T.NACIONALIDAD         ,--(N)
                                          T.APELLIDO1            ,--(N)
                                          T.APELLIDO2            ,--(N)
                                          T.APE_CASADA           ,--(N)
                                          T.NOMBRE1              ,--(N)
                                          T.NOMBRE2              ,--(N)
                                          T.FEC_NACIMIENTO       ,--(N)
                                          T.COD_SEXO             ,--(N)
                                          T.EST_CIVIL            ,--(N)
                                          T.CALLE                ,--(N)
                                          NULL                   ,--(N)=>NRO_PUERTA
                                          T.APARTAMENTO          ,--(N)
                                          T.PISO                 ,--(N)
                                          T.COMPLEMENTO          ,--(N)
                                          NULL                   ,--(N)=>KILOMETRO
                                          NULL                   ,--(N)=>MANZANA
                                          NULL                   ,--(N)=>LOTE
                                          NULL                   ,--(N)=>BLOCK
                                          NULL                   ,--(N)=>ESQUINA1
                                          NULL                   ,--(N)=>ESQUINA2
                                          T.PENSION_HOTEL        ,--(N)
                                          NULL                   ,--(N)=>PROT.INQUILINO
                                          NULL                   ,--(N)=>ID_CIUDAD
                                          T.CIU_DISTRITO         ,--(N)
                                          T.LOCAL_BARRIO         ,--(N)
                                          T.DEPARTAMENTO         ,--(N)
                                          NULL                   ,--(N)=>COD_POSTAL
                                          T.TELEFONO             ,--(N)
                                          T.EMPRESA              ,--(N)
                                          NULL                   ,--(N)=>OCUT.CARGO
                                          NULL                   ,--(N)=>PROFESION
                                          T.CALLE_EMP            ,--(N)
                                          NULL                   ,--(N)=>NRO_PUERTA_EMP
                                          T.APARTAMENTO_EMP      ,--(N)
                                          T.PISO_EMP             ,--(N)
                                          T.COMPLEMENTO_EMP      ,--(N)
                                          NULL                   ,--(N)=>KILONETRO_RMP
                                          NULL                   ,--(N)=>MANZANA_EMP
                                          NULL                   ,--(N)=>LOTE_EMP
                                          NULL                   ,--(N)=>BLOCK_EMP
                                          NULL                   ,--(N)=>ESQUINA1_EMP
                                          NULL                   ,--(N)=>ESQUINA2_EMP
                                          NULL                   ,--(N)=>ID_CIUDAD_EMP
                                          T.CIUDAD_DISTRITO_EMP  ,--(N)
                                          T.LOCALIDAD_BARRIO_EMP ,--(N)
                                          T.DEPARTAMENTO_EMP     ,--(N)
                                          NULL                   ,--(N)=>COD_POSTAL_EMP
                                          NULL                   ,--(N)=>INGRESO_EMP
                                          T.TELEFONO_EMP         ,--(N)
                                          NULL                   ,--(N)=>TIPO_DOC_CONY
                                          NULL                   ,--(N)=>PAIS_DOC_CONY
                                          NULL                   ,--(N)=>DOCUMENTO_CONY
                                          NULL                   ,--(N)=>NACIONALIDAD_CONY
                                          NULL                   ,--(N)=>APELLIDO1_CONY
                                          NULL                   ,--(N)=>APELLIDO2_CONY
                                          NULL                   ,--(N)=>APE_CASADA_CONY
                                          NULL                   ,--(N)=>NOMBRE1_CONY
                                          NULL                   ,--(N)=>NOMBRE2_CONY
                                          T.MOTIVO               ,--(S)
                                          T.TIP_DEUDOR           ,--(S)
                                          NULL                   );--(N)=>DAT_EXTRAS
          Else -- Consulta Masiva, va en Excel.-
             v_xml := null;
          End If;
          IF v_verificacion in ('I') and p_tip_ejecucion = 'P' THEN -- No existe, es necesario insertar

                v_nro_documento := t.nro_documento;

                -- ba_personas
                SELECT s_cod_persona.nextval
                  INTO v_cod_persona
                  FROM dual;

                begin
                    select a.cod_pais
                      into v_cod_pais
                      from ba_paises a
                     where a.cod_pai_iso = upper(t.pai_documento);
                exception
                  when no_data_found then
                       v_error := 'Error al buscar Pais. Documento Nro: '||t.nro_documento||' '||SQLERRM;
                  end;

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
                                    VALUES (v_cod_persona      ,
                                            t.Nombre1||' '||t.Nombre2||' '||t.Apellido1||' '||t.Apellido2,
                                            decode(t.tip_documento,'RUC','J','F'),
                                            v_cod_tip_documento,
                                            t.Nro_Documento    ,
                                            v_cod_pais         ,
                                            701                ,
                                            'V'                ,
                                            'CONSULTA MASIVA EQUIFAX');
                EXCEPTION
                   WHEN OTHERS THEN
                      v_verificacion := 'E';
                      v_error        := 'Error al insertar datos en BA_PERSONAS. Documento Nro= '||t.Nro_Documento||' '||SQLERRM;
                END;

                v_lugar := '2-Obtengo estado Civil';
                IF t.est_civil IS NOT NULL THEN
                   -- ba_per_fisicas
                   BEGIN
                      SELECT val_minimo
                        INTO v_est_civil
                        FROM ba_cod_referencias
                       WHERE dominio    = 'COD_EST_CIVIL'
                         AND val_minimo = t.est_civil;
                   EXCEPTION
                      WHEN no_data_found THEN
                         v_verificacion := 'E';
                         v_error := 'No existe estado civil definido. Documento Nro= '||t.Nro_Documento||' - '||SQLERRM;
                      WHEN OTHERS THEN
                         v_verificacion := 'E';
                         v_error := 'Error al buscar el Estado Civil Documento. Nro= '||t.nro_documento||' '||SQLERRM;
                   END;
                ELSE
                   v_est_civil := 'S';
                END IF;
                If t.tip_documento <> 'RUC' Then
                    BEGIN
                       v_lugar := '3-Insert BA_PER_FISICAS';
                       INSERT INTO ba_per_fisicas (cod_persona          ,
                                                   pri_nombre           ,
                                                   pri_apellido         ,
                                                   est_civil            ,
                                                   cod_sexo             ,
                                                   cod_pai_nacionalidad ,
                                                   seg_nombre           ,
                                                   seg_apellido         ,
                                                   fec_nacimiento       )
                                            VALUES(v_cod_persona        ,
                                                   t.nombre1            ,
                                                   t.apellido1          ,
                                                   v_est_civil          ,
                                                   t.cod_sexo           ,
                                                   v_cod_pais           ,
                                                   t.nombre2            ,
                                                   t.apellido2          ,
                                                   t.fec_nacimiento     );
                    EXCEPTION
                       WHEN OTHERS THEN
                          v_verificacion := 'E';
                          v_error := 'Error al insertar datos en BA_PER_FISICAS. Documento Nro= '||t.nro_documento||' '||SQLERRM;
                    END;
                Elsif t.tip_documento = 'RUC' Then
                    BEGIN
                       v_lugar := '4-Insert BA_PER_JURIDICAS';
                       INSERT INTO ba_per_juridicas (cod_persona          ,
                                                     raz_social           ,
                                                     nom_comercial        ,
                                                     fec_apertura         )
                                              VALUES(v_cod_persona        ,
                                                     t.nombre1            ,
                                                     t.nombre1            ,
                                                     t.fec_nacimiento     );
                    EXCEPTION
                       WHEN OTHERS THEN
                          v_verificacion := 'E';
                          v_error := 'Error al insertar datos en BA_PER_JURIDICAS. Documento Nro= '||t.nro_documento||' '||SQLERRM;
                    END;
                End If;
                begin
                    update ge_equ_consulta_tmp a
                       set a.estado      = V_VERIFICACION,
                           a.fec_datos   = pag_cal.FU_OBT_FEC_ACTUAL(1),
                           a.cod_cliente = v_cod_entidad
                     where a.rowid       = t.rowid;
                Exception
                    when others then
                         raise_application_error(-20000,'Error Actualizando Registro a Procesar '||sqlerrm);
                End;
                --FATCA
                PAE_FAT.PR_ACT_PER_FATCA(v_cod_persona,'F',null,'S', v_men_fatca, 'S');

                -- Insertar en la tabla cabecera maestra de consultas a Equifax
                Begin
                    update ge_equ_consulta_tmp a
                      set COD_PERSONA   = V_COD_PERSONA,
                          DAT_CONSULTA  = V_XML,
                          ESTADO        = 'P',
                          a.cod_cliente = v_cod_entidad
                    where a.rowid = t.rowid;
                Exception
                    when others Then
                         raise_application_error(-20000,'Error Insertado Conuslta '||sqlerrm);
                End;
          ElsIf v_verificacion in ('P', 'A') and p_tip_ejecucion = 'P' Then

                Begin
                    update ge_equ_consulta_tmp a
                      set COD_PERSONA   = V_COD_PERSONA,
                          a.cod_cliente = v_cod_entidad,
                          DAT_CONSULTA  = V_XML,
                          ESTADO        = 'P'
                    where a.rowid = t.rowid;
                Exception
                    when others Then
                         raise_application_error(-20000,'Error Insertado Conuslta '||sqlerrm);
                End;
                If v_verificacion = 'A' and v_error like ('Persona recientemente consultada:%') Then
                   begin
                        insert into ge_equ_consultas_det_his(fecha,hora,cod_persona,nom_campo,res_consulta)
                            select a.fecha, to_char(sysdate,'HH24:MM:SS') hora, a.cod_persona, a.nom_campo,
                                   a.res_consulta
                             from ge_equ_consultas_det a
                            where a.cod_persona = v_cod_persona;

                        delete ge_equ_consultas_det a where a.cod_persona = v_cod_persona;
                        delete ge_equ_consultas_cab a where a.cod_persona = v_cod_persona;

                   Exception
                        when Others Then
                             raise_application_error(-20000,'Error al insertar al historico '||sqlerrm);
                   end;
                End If;
          Else
              begin
                  update ge_equ_consulta_tmp a
                     set a.estado      = v_verificacion,
                         a.error       = v_error,
                         a.cod_cliente = v_cod_entidad
                   where a.rowid       = t.rowid;
              Exception
                  when others then
                       raise_application_error(-20000,'Error Actualizando Registro con error '||sqlerrm);
              End;
          End If;
      End If;
   END LOOP;
   --COMMIT;
EXCEPTION
   WHEN OTHERS THEN
        --raise_application_error(-20019, v_nro_documento||'-'||v_lugar||'-'||SQLERRM);
        dbms_output.put_line('Error '||v_nro_documento||'-'||v_lugar||'-'||SQLERRM);
END;
/

