CREATE OR REPLACE PROCEDURE IT.PRT_GEN_DAT_ALTAS_ANTERIOR(P_COD_PROCESADORA IN VARCHAR2)
 IS
BEGIN
  NULL;
END;
 /*  \*Definicion de variables utilizadas*\
   c_tip_implementacion       GE_PAR_GENERALES.TIP_IMPLEMENTACION%TYPE := fug_obt_tip_implementacion;
   v_sec_env_datos            TA_ENV_CUENTAS.SEC_ENV_DATOS%TYPE;
   v_lugar                    VARCHAR2(100) := 'INICIANDO';
   v_fec_actual               GE_CALENDARIOS.FEC_ACTUAL%TYPE;
   v_nro_secuencia            NUMBER(4);
   v_cod_persona              BA_PERSONAS.COD_PERSONA%TYPE;
   v_cod_campana              GE_SOLICITUDES.COD_CAMPANA%TYPE;
   v_des_ciudad               BA_CIUDADES.DESCRIPCION%TYPE;
   v_tel_cliente              VARCHAR2(25);
   v_cod_modulo               GE_MODALIDADES.COD_MODULO%TYPE;
   v_cod_modalidad            GE_MODALIDADES.COD_MODALIDAD%TYPE;
   v_dir_cliente              varchar2(90);--BA_DIRECCIONES.DIRECCION%TYPE;
   v_dir_extendida            VARCHAR2(150);
   v_observacion              BA_DIRECCIONES.OBSERVACION%TYPE;
   v_nro_solicitud            GE_SOLICITUDES.NRO_SOLICITUD%TYPE;
   v_cod_per_codeudor         BA_PERSONAS.COD_PERSONA%TYPE;
   v_nom_codeudor             BA_PERSONAS.NOM_COMPLETO%TYPE;
   v_nro_doc_codeudor         BA_PERSONAS.NRO_DOCUMENTO%TYPE;
   v_cod_banco                TA_ENV_CUENTAS.COD_BANCO%TYPE;
   v_sig_nro_cuenta           varchar2(15);   
   -------------
   v_cod_sucursal             TA_SUCURSALES.COD_SUCURSAL%TYPE;
   v_cod_encargado            TA_ENV_CUENTAS.COD_ENCARGADO%TYPE;
   -------------
   v_cod_retencion            TA_ENV_CUENTAS.COD_RETENCION%TYPE;
   v_cod_procesadora          VARCHAR2(10);
   v_nro_doc_procesadora      TA_ENV_CUENTAS.NRO_DOC_PROCESADORA%TYPE;
   v_nro_doc_cod_procesadora  TA_ENV_CUENTAS.NRO_DOC_PROCESADORA%TYPE;
   v_nro_doc_adi_procesadora  TA_ENV_CUENTAS.NRO_DOC_PROCESADORA%TYPE;
   v_cod_usu_promotor         GE_SOLICITUDES.COD_USU_PROMOTOR%TYPE;
   v_cod_oficina              GE_PAR_GENERALES.COD_OFI_MATRIZ%TYPE;
   --
   v_existe                    VARCHAR2(1):='N';
   v_nro_cuenta               ta_tarjetas.nro_cuenta%type;
   v_nro_tarjeta              ta_tarjetas.nro_tarjeta%type;
   v_tip_doc_codeudor         ba_personas.cod_tip_documento%type;
   v_tip_doc_ci               ba_personas.cod_tip_documento%type;
   v_nro_doc_adicional        ba_personas.nro_documento%type;
   v_tip_doc_adicional        ba_personas.cod_tip_documento%type;
   v_nro_documento            ba_personas.nro_documento%type;
   v_tip_per_codeudor         ba_personas.tipo%type;
   v_tipo                     ta_env_tarjetas.tip_tarjeta%type;
   v_nombre                   ba_personas.nom_completo%type;

     \*Cursor de Cuentas, titulares*\
   CURSOR c_cuentas
       IS select  distinct t.cod_persona,t.Tipo, t.nro_solicitud,t.fec_solicitud,t.cod_oficina,t.cod_modulo, t.cod_modalidad,
                 t.cod_usu_promotor, t.fec_solicitud, t.fec_aprobacion, t.cod_causa,
                 a.cod_tip_tarjeta, null tip_cierre, a.tip_cobro tip_cob, a.tip_tas_financiacion,
                 a.tip_com_emision, decode(a.franqueo,'N',0,'S',1) franqueo, \*a.tip_cuenta*\decode(z.tipo,'F',1,2) tip_cuenta, substr(a.afinidad,3,2) afinidad, nvl(a.cta_vip,'N') cta_vip,
                 a.tip_gas_financiero, nvl(a.cta_personalizada,'N') cta_personalizada,
                 a.tip_generacion, z.nom_completo,
                 z.nro_documento, z.cod_tip_documento, z.tipo tip_persona,
                 a.afinidad tip_afinidad
            from tv_solicitudes t, ba_personas z, ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and a.cod_ent_procesadora = v_cod_procesadora
             \*and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                     c_tip_implementacion = 1 )*\
             and t.tipo = 'T'
             and z.cod_persona = t.cod_persona
        UNION
          select distinct t.cod_persona,t.Tipo, t.nro_solicitud,t.fec_solicitud,t.cod_oficina,t.cod_modulo, t.cod_modalidad,
                 t.cod_usu_promotor, t.fec_solicitud, t.fec_aprobacion, t.cod_causa,
                 a.cod_tip_tarjeta, null tip_cierre, a.tip_cobro tip_cob, a.tip_tas_financiacion,
                 a.tip_com_emision, decode(a.franqueo,'N',0,'S',1) franqueo, \*a.tip_cuenta*\decode(z.tipo,'F',1,2) tip_cuenta, substr(a.afinidad,3,2) afinidad, a.cta_vip,
                 a.tip_gas_financiero, a.cta_personalizada, a.tip_generacion, z.nom_completo,
                 z.nro_documento, z.cod_tip_documento, z.tipo tip_persona,
                 a.afinidad tip_afinidad                 
            from tv_solicitudes t, ba_personas z, ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and a.cod_ent_procesadora = v_cod_procesadora
            \* and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )*\
             and t.tipo = 'T'
             and z.cod_persona = t.cod_persona
             and EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana <> nvl( x.cod_campana, 0 )
                            and x.cod_campana IS NULL );

    \* Cursor para Novedades de cuentas de Bancard*\
    CURSOR novedades
        IS select distinct n.*
             from ta_cta_tarjetas_nov n, ta_cta_tarjetas j, ta_tipos tp
            where nvl( n.enviado, 'N' ) <> 'S'
              and nvl(n.aprobado, 'N') = 'S'
              and n.nro_cuenta = j.nro_cuenta
              and tp.cod_modulo = j.cod_modulo
              and tp.cod_modalidad = j.cod_modalidad
              and (tp.cod_oficina = j.cod_oficina or tp.cod_oficina is null)
              and tp.cod_ent_procesadora = v_cod_procesadora;

    \*Cursor de Novedades de tarjetas*\
    CURSOR tar_modificadas
        is select m.*, m.cod_tip_documento
             from tv_tar_modificadas m;
             
    \*Cursor de Tarjetas de Adicionales x solicitud*\
    --los adicionales sólo pueden ser personas físicas
   CURSOR c_tarjetas_adicional
          --personas fisicas / SIN campaña --
       IS select distinct r.cod_persona, r.nom_embozado, r.nro_solicitud, z.nro_documento, '1' tipo,
                 y.pri_apellido ||', '|| y.pri_nombre nom_completo, substr(a.afinidad,3,2) afinidad, a.cod_tip_tarjeta,
                 a.tip_generacion, a.plz_dur_tarjeta, t.cod_oficina,
                 t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona,
                 t.nro_cuenta
            from tv_solicitudes t, ta_sol_adicionales r, ba_personas z, ba_per_fisicas y,
                 ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             \*and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                     c_tip_implementacion = 1 )*\
             and a.cod_ent_procesadora = v_cod_procesadora
             and t.tipo = 'A'
             and r.nro_solicitud = t.nro_solicitud
             and r.cod_persona = t.cod_persona
             and r.nro_solicitud = v_nro_solicitud
             and z.cod_persona = r.cod_persona
             and y.cod_persona = r.cod_persona
        UNION
          --personas fisicas / CON campaña --
          select distinct r.cod_persona, r.nom_embozado, r.nro_solicitud, z.nro_documento, '1' tipo,
                 y.pri_apellido ||', '|| y.pri_nombre nom_completo, substr(a.afinidad,3,2) afinidad, a.cod_tip_tarjeta,
                 a.tip_generacion, a.plz_dur_tarjeta, t.cod_oficina,
                 t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona,
                 t.nro_cuenta                 
            from tv_solicitudes t, ta_sol_adicionales r, ba_personas z, ba_per_fisicas y,
                 ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             \*and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )*\
             and a.cod_ent_procesadora = v_cod_procesadora
             and t.tipo = 'A'
             and r.nro_solicitud = t.nro_solicitud
             and r.cod_persona = t.cod_persona
             and r.nro_solicitud = v_nro_solicitud
             and z.cod_persona = r.cod_persona
             and y.cod_persona = r.cod_persona
             and EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana <> nvl( x.cod_campana, 0 )
                            and x.cod_campana IS NULL )
             and NOT EXISTS( select 1
                            from ta_tipos x
                           where t.cod_modulo = x.cod_modulo
                             and t.cod_modalidad = x.cod_modalidad
                             and a.cod_ent_procesadora = x.cod_ent_procesadora
                             and t.cod_campana = nvl( x.cod_campana, 0 ) );
        \*UNION
          --personas juridicas / SIN campaña --
          select distinct r.cod_persona, r.nom_embozado, r.nro_solicitud, z.nro_documento, '1' tipo,
                 y.raz_social nom_completo,substr(a.afinidad,3,2) afinidad,a.cod_tip_tarjeta,a.tip_generacion,
                 a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona
            from tv_solicitudes t, ta_sol_adicionales r, ba_personas z, ba_per_juridicas y,
                 ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                     c_tip_implementacion = 1 )
             and a.cod_ent_procesadora = v_cod_procesadora
             and t.tipo = 'A'
             and r.nro_solicitud = t.nro_solicitud
             and r.nro_solicitud = v_nro_solicitud
             and z.cod_persona = r.cod_persona
             and y.cod_persona = r.cod_persona
        UNION
          --personas juridicas / CON campaña --
          select distinct r.cod_persona, r.nom_embozado, r.nro_solicitud, z.nro_documento, '1' tipo,
                 y.raz_social nom_completo,substr(a.afinidad,3,2) afinidad,a.cod_tip_tarjeta,a.tip_generacion,
                 a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona
            from tv_solicitudes t, ta_sol_adicionales r, ba_personas z, ba_per_juridicas y,
                 ta_tipos a
           where t.cod_estado = 'APR'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
             and a.cod_ent_procesadora = v_cod_procesadora
             and t.tipo = 'A'
             and r.nro_solicitud = t.nro_solicitud
             and r.nro_solicitud = v_nro_solicitud
             and z.cod_persona = r.cod_persona
             and y.cod_persona = r.cod_persona
             and EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana <> nvl( x.cod_campana, 0 )
                            and x.cod_campana IS NULL )
             and NOT EXISTS( select 1
                            from ta_tipos x
                           where t.cod_modulo = x.cod_modulo
                             and t.cod_modalidad = x.cod_modalidad
                             and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana = nvl( x.cod_campana, 0 ) );*\

  \*Cursor de Tarjetas de Principales x solicitud*\ 
  --Sólo las Físicas para crear ta_env_tarjetas, las jurídicas no envían
  CURSOR c_tarjetas_principal
      --personas fisicas / SIN campaña--
      IS select distinct t.cod_persona, t.nom_embozado, t.nro_solicitud, z.nro_documento, '0' tipo,
                y.pri_apellido || ', ' || y.pri_nombre nom_completo, substr(a.afinidad,3,2) afinidad, a.cod_tip_tarjeta,
                a.tip_generacion, a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona,
                t.nro_cuenta
           from tv_solicitudes t, ba_personas z, ba_per_fisicas y, ta_tipos a
          where t.cod_estado = 'APR'
            and t.cod_modulo = a.cod_modulo
            and t.cod_modalidad = a.cod_modalidad
            and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
            and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
            and a.cod_ent_procesadora = v_cod_procesadora
            and t.tipo = 'T'
            and t.nro_solicitud = v_nro_solicitud
            and z.cod_persona = t.cod_persona
            and y.cod_persona = t.cod_persona
       UNION
         --personas fisicas / CON campaña--
         select distinct t.cod_persona, t.nom_embozado, t.nro_solicitud, z.nro_documento, '0' tipo,
                y.pri_apellido || ', ' || y.pri_nombre nom_completo, substr(a.afinidad,3,2) afinidad, a.cod_tip_tarjeta,
                a.tip_generacion, a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona,
                t.nro_cuenta
           from tv_solicitudes t, ba_personas z, ba_per_fisicas y, ta_tipos a
          where t.cod_estado = 'APR'
            and t.cod_modulo = a.cod_modulo
            and t.cod_modalidad = a.cod_modalidad
            and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
            and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
            and a.cod_ent_procesadora = v_cod_procesadora
            and t.tipo = 'T'
            and t.nro_solicitud = v_nro_solicitud
            and z.cod_persona = t.cod_persona
            and y.cod_persona = t.cod_persona
            and EXISTS( select 1
                          from ta_tipos x
                         where t.cod_modulo = x.cod_modulo
                           and t.cod_modalidad = x.cod_modalidad
                           and a.cod_ent_procesadora = x.cod_ent_procesadora
                           and t.cod_campana <> nvl( x.cod_campana, 0 )
                           and x.cod_campana IS NULL )
            and NOT EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana = nvl( x.cod_campana, 0 ) )
       \*UNION
         --personas juridicas / SIN campaña--
         select distinct t.cod_persona, t.nom_embozado, t.nro_solicitud, z.nro_documento, '0' tipo,
                y.raz_social nom_completo,substr(a.afinidad,3,2) afinidad,a.cod_tip_tarjeta,a.tip_generacion,
                a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona
           from tv_solicitudes t, ba_personas z, ba_per_juridicas y, ta_tipos a
          where t.cod_estado = 'APR'
            and t.cod_modulo = a.cod_modulo
            and t.cod_modalidad = a.cod_modalidad
            and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
            and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
            and a.cod_ent_procesadora = v_cod_procesadora
            and t.tipo = 'T'
            and t.nro_solicitud = v_nro_solicitud
            and z.cod_persona = t.cod_persona
            and y.cod_persona = t.cod_persona
       UNION
         --personas juridicas / CON campaña--
         select distinct t.cod_persona, t.nom_embozado, t.nro_solicitud, z.nro_documento, '0' tipo,
                y.raz_social nom_completo,substr(a.afinidad,3,2) afinidad,a.cod_tip_tarjeta,a.tip_generacion,
                a.plz_dur_tarjeta, t.cod_oficina,
                t.cod_usu_promotor, t.cod_campana, z.cod_tip_documento, z.tipo tip_persona
           from tv_solicitudes t, ba_personas z, ba_per_juridicas y, ta_tipos a
          where t.cod_estado = 'APR'
            and t.cod_modulo = a.cod_modulo
            and t.cod_modalidad = a.cod_modalidad
            and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
            and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
            and a.cod_ent_procesadora = v_cod_procesadora
            and t.tipo = 'T'
            and t.nro_solicitud = v_nro_solicitud
            and z.cod_persona = t.cod_persona
            and y.cod_persona = t.cod_persona
            and EXISTS( select 1
                          from ta_tipos x
                         where t.cod_modulo = x.cod_modulo
                           and t.cod_modalidad = x.cod_modalidad
                           and a.cod_ent_procesadora = x.cod_ent_procesadora
                           and t.cod_campana <> nvl( x.cod_campana, 0 )
                           and x.cod_campana IS NULL )
            and NOT EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and t.cod_campana = nvl( x.cod_campana, 0 ) )*\
          order by 3, 6;

  \* Cursor de Cuentas enviadas (titulares ya enviados)*\
   CURSOR c_cue_enviadas 
       IS select distinct t.*,
                 a.cod_tip_tarjeta, null tip_cierre, a.tip_cobro tip_cob, a.tip_tas_financiacion,
                 a.tip_com_emision, decode(a.franqueo,'N',0,'S',1) franqueo, \*a.tip_cuenta*\decode(z.tipo,'F',1,2) tip_cuenta, substr(a.afinidad,3,2) afinidad, nvl(a.cta_vip,'N') cta_vip,
                 a.tip_gas_financiero, nvl(a.cta_personalizada,'N') cta_personalizada,
                 a.tip_generacion, z.nom_completo,
                 z.nro_documento, ct.nro_cuenta nro_cta_actual, z.cod_tip_documento, z.tipo tip_persona
            from ta_solicitudes t, ba_personas z, ta_tipos a, ta_cta_tarjetas ct
           where t.cod_estado = 'TIA'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and a.cod_ent_procesadora = v_cod_procesadora
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) = nvl( a.cod_campana, 0 ) ) or
                     c_tip_implementacion = 1 )
             and z.cod_persona = t.cod_persona
             and t.nro_solicitud = ct.nro_solicitud
             and exists (select 0      --q tenga adicional sin enviar
                           from ta_sol_adicionales x
                          where x.nro_solicitud = t.nro_solicitud
                            and x.cod_estado ='APR')
        UNION
          select distinct t.*,
                 a.cod_tip_tarjeta, null tip_cierre, a.tip_cobro tip_cob, a.tip_tas_financiacion,
                 a.tip_com_emision, decode(a.franqueo,'N',0,'S',1) franqueo, \*a.tip_cuenta*\decode(z.tipo,'F',1,2) tip_cuenta, substr(a.afinidad,3,2) afinidad, a.cta_vip,
                 a.tip_gas_financiero, a.cta_personalizada, a.tip_generacion, z.nom_completo,
                 z.nro_documento, ct.nro_cuenta nro_cta_actual, z.cod_tip_documento, z.tipo tip_persona
            from ta_solicitudes t, ba_personas z, ta_tipos a, ta_cta_tarjetas ct
           where t.cod_estado = 'TIA'
             and t.cod_modulo = a.cod_modulo
             and t.cod_modalidad = a.cod_modalidad
             and a.cod_ent_procesadora = v_cod_procesadora
             and (t.cod_oficina = a.cod_oficina or a.cod_oficina is null)
             and ( ( c_tip_implementacion <> 1 and nvl( t.cod_campana, 0 ) <> nvl( a.cod_campana, 0 ) ) or
                    c_tip_implementacion = 1 )
             and z.cod_persona = t.cod_persona
             and t.nro_solicitud = ct.nro_solicitud
             and exists (select 0      --q tenga adicional sin enviar
                           from ta_sol_adicionales x
                          where x.nro_solicitud = t.nro_solicitud
                            and x.cod_estado ='APR')
             and EXISTS( select 1
                           from ta_tipos x
                          where t.cod_modulo = x.cod_modulo
                            and t.cod_modalidad = x.cod_modalidad
                            and a.cod_ent_procesadora = x.cod_ent_procesadora
                            and (t.cod_oficina = x.cod_oficina or x.cod_oficina is null)
                            and t.cod_campana <> nvl( x.cod_campana, 0 )
                            and x.cod_campana IS NULL );

    \* cursor de tarjetas no renovadas*\
     CURSOR no_renovacion
         is select ti.cod_ent_procesadora, t.nro_tarjeta, t.nro_cuenta,
                   y.pri_apellido || ', ' || y.pri_nombre nom_usuario,
                   t.cod_persona, z.nro_documento, ti.plz_dur_tarjeta,
                   '0' tipo, ti.cod_tip_tarjeta, substr(ti.afinidad,3,2) afinidad,
                   ti.tip_generacion, t.nom_embozar, c.nro_solicitud,
                   c.cod_oficina,
                   c.cod_usu_promotor, c.cod_campana, z.cod_tip_documento, z.tipo tip_persona
              from ta_tarjetas t    ,
                   ta_cta_tarjetas c,
                   ta_tipos ti      ,
                   ba_personas z    ,
                   ba_per_fisicas y
             where t.cod_estado    = 15
               and c.nro_cuenta    = t.nro_cuenta
               and c.cod_modulo    = ti.cod_modulo
               and c.cod_modalidad = ti.cod_modalidad
               and (c.cod_oficina = ti.cod_oficina or ti.cod_oficina is null)
               and t.cod_persona   = z.cod_persona
               and z.cod_persona   = y.cod_persona
               and ti.cod_ent_procesadora = v_cod_procesadora
               and not exists(select 1
                                from ta_env_tarjetas_his h
                               where h.cod_procesadora = ti.cod_ent_procesadora
                                 and h.nro_tarjeta     = t.nro_tarjeta
                                 and h.estado          = 'E');

  PROCEDURE lp_dir_envio is
  BEGIN
    \*Carga los datos de la direccion y telefono de envio*\
    v_lugar := 'lp_dir_envio';
    ---0. limpio los valores a leer ------------------------------------
    v_dir_cliente   := NULL;
    v_des_ciudad    := NULL;
    v_tel_cliente   := NULL;
    v_observacion   := NULL;
    v_dir_extendida := NULL;
    begin
      select t.area||decode(t.area, null, null, '-')||t.telefono tel_cliente
        into v_tel_cliente
        from ba_telefonos t 
       where t.cod_persona= v_cod_persona
          and t.principal = 'S';
    exception
      when others then
          v_tel_cliente := null;
    end;
    begin
    ---1. Leo la vista de acuerdo a los datos que me pasa --------------
    select substr( decode( e.tip_envio, 'D', d.direccion||decode(numero,null,'',' '||numero), -- Direccion
                                        'C', 'CASILLERO: ' || e.referencia, -- Casillero
                                        'A', 'CASILLA DE CORREO: ' || e.referencia, -- Casilla de correo
                                        'R', 'RETENER EN '|| o.descripcion ), 1, 50 ) dir_envio,
           c.descripcion des_ciudad,
           d.observacion --observacion--
      into v_dir_cliente, v_des_ciudad,  v_observacion
      from ba_barrios b, ba_ciudades c, ba_paises p, 
           ba_direcciones d, ge_dir_retenciones o, ge_dir_envios e
     where p.cod_pais(+) = d.cod_pais
       and c.cod_pais(+) = d.cod_pais
       and c.cod_ciudad(+) = d.cod_ciudad
       and b.cod_pais(+) = d.cod_pais
       and b.cod_ciudad(+) = d.cod_ciudad
       and b.cod_barrio(+) = d.cod_barrio
       and d.cod_persona(+) = e.cod_persona
       and d.cod_direccion(+) = e.referencia
       and o.cod_dir_retencion(+) = e.referencia
       and e.cod_persona = v_cod_persona
       and e.nro_cuenta is null;
    exception   
      when no_data_found then
          ---1. Leo la vista de acuerdo a los datos que me pasa --------------
          select substr( d.direccion||decode(numero,null,'',' '||numero), 1, 50 ) dir_envio,
                 c.descripcion des_ciudad,
                 d.observacion --observacion--
            into v_dir_cliente, v_des_ciudad, v_observacion
            from ba_barrios b, ba_ciudades c, ba_paises p,
                 ba_direcciones d
           where p.cod_pais(+) = d.cod_pais
             and c.cod_pais(+) = d.cod_pais
             and c.cod_ciudad(+) = d.cod_ciudad
             and b.cod_pais(+) = d.cod_pais
             and b.cod_ciudad(+) = d.cod_ciudad
             and b.cod_barrio(+) = d.cod_barrio
             and d.cod_persona(+) = v_cod_persona
             and d.principal(+) = 'S';
    end;   
    IF v_tel_cliente IS NULL THEN
      select x.area || decode( x.area, NULL, NULL, '-' ) || x.telefono
        into v_tel_cliente
        from ba_telefonos x
       where x.cod_persona = v_cod_persona
         and x.principal = 'N'
         and x.cod_telefono = ( select min( y.cod_telefono )
                                  from ba_telefonos y
                                 where y.cod_persona = v_cod_persona
                                   and y.principal = 'N'
                                   and y.telefono IS NOT NULL );
    END IF;
    --armar la direccion extendida--
    select substr( v_dir_cliente || decode( v_des_ciudad, NULL, NULL, '-' ) ||
                   v_des_ciudad || decode( v_observacion, NULL, NULL, '-' ) ||
                   v_observacion, 1, 150 )
      into v_dir_extendida
      from dual;
    ---------------------------------------------------------------------
  EXCEPTION
    when others then
      v_dir_cliente := 'SIN DIRECCION DE ENVIO';
  END lp_dir_envio;

  PROCEDURE lp_dat_codeudor IS
  BEGIN
    \*Carga los datos del codeudor si tiene*\
    v_lugar := 'lp_dat_codeudor';
    ---0. limpio los valores a leer ------------------------------------
    v_cod_per_codeudor := NULL;
    v_nom_codeudor     := NULL;
    v_nro_doc_codeudor := NULL;
    v_tip_per_codeudor := null;

    ---1. Leo la vista de acuerdo a los datos que me pasa --------------
    select x.nro_garantia cod_persona, substr( y.nom_completo, 1, 30 ), y.nro_documento, 
           y.cod_tip_documento, y.tipo
      into v_cod_per_codeudor, v_nom_codeudor, v_nro_doc_codeudor, 
           v_tip_doc_codeudor, v_tip_per_codeudor
      from ta_sol_garantias x, ba_personas y
     where x.nro_solicitud = v_nro_solicitud
       and x.nro_garantia = y.cod_persona
       and x.cod_garantia = 2 --Solo envia el codeudor, si tiene--
       and rownum = 1;
    ---------------------------------------------------------------------
  EXCEPTION
    when others then
      NULL;
  END lp_dat_codeudor;

  PROCEDURE lp_car_pardinamicos IS
    v_sol_cta ta_tarjetas.nro_cuenta%type;
  BEGIN
    \*Carga todos los parametros dinamicos necesarios*\
    v_lugar := 'lp_car_pardinamicos';
    ---0. limpio los valores a leer ------------------------------------
    v_cod_banco          := null;
    v_cod_sucursal       := null;
    v_cod_retencion      := 1;
    if v_nro_cuenta is not null then
       v_sol_cta := v_nro_cuenta;
    else
        v_sol_cta := v_nro_solicitud;
    end if;

    ---1. Leo la vista de acuerdo a los datos que me pasa --------------
    v_cod_banco     := fug_obt_parentes(v_cod_procesadora,'COD_BANCO');
    
    --sólo si tiene promotor
    if v_cod_usu_promotor is not null then
      v_lugar := 'Obt. Usuario';
      BEGIN
        select cod_usu_ente
          into v_cod_encargado
          from ge_ent_usuarios
         where cod_ente = v_cod_procesadora
           and cod_usuario = v_cod_usu_promotor;
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20121, v_lugar || ': No encuentra cód. de encargado ('||v_cod_usu_promotor||') para Sol. / Cta. '||v_sol_cta||'. ' || sqlerrm );
          END IF;
      END;
    end if;
    v_lugar := 'Obt. Sucursal';
    If v_cod_campana is not null then
      v_lugar := v_lugar||'-'||'Campaña : '||v_cod_campana;
      BEGIN
        select cod_sucursal
          into v_cod_sucursal
          from ta_sucursales
          where cod_ent_procesadora = v_cod_procesadora
            and cod_oficina = v_cod_oficina
            and cod_campana = v_cod_campana
            and activo = 'S'
            and ( c_tip_implementacion not in (2, 3) OR
                  cod_sucursal = ( select min( cod_sucursal )
                                     from ta_sucursales
                                    where cod_ent_procesadora = v_cod_procesadora
                                      and cod_oficina = v_cod_oficina
                                      and cod_campana = v_cod_campana
                                      and activo = 'S' ) );
      EXCEPTION
        when no_data_found then
          BEGIN
            select cod_sucursal
              into v_cod_sucursal
              from ta_sucursales
              where cod_ent_procesadora = v_cod_procesadora
                and cod_oficina = v_cod_oficina
                and activo = 'S'
                and rownum = 1;
          EXCEPTION
            when others then
              IF sqlcode <= -20000 THEN
                RAISE;
              ELSE
                RAISE_APPLICATION_ERROR( -20122, v_lugar || ': No encuentra código de sucursal ('||v_cod_oficina||')' || sqlerrm );
              END IF;
          END;
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20123, v_lugar || ': No encuentra código de sucursal ('||v_cod_oficina||')' || sqlerrm );
          END IF;
      END;
    ELSE
      BEGIN
        select cod_sucursal
          into v_cod_sucursal
          from ta_sucursales
         where cod_ent_procesadora = v_cod_procesadora
           and cod_oficina = v_cod_oficina
           and activo = 'S'
           and cod_campana IS NULL
           and ( c_tip_implementacion not in (2,3) OR
                 cod_sucursal = ( select min( cod_sucursal )
                                    from ta_sucursales
                                   where cod_ent_procesadora = v_cod_procesadora
                                     and cod_oficina = v_cod_oficina
                                     and cod_campana IS NULL
                                     and cod_sucursal > 0
                                     and activo = 'S' ) );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20124, v_lugar || ': No encuentra código de sucursal ('||v_cod_oficina||')'  || sqlerrm );
          END IF;
      END;
    END IF;
  END lp_car_pardinamicos;
  
FUNCTION lf_obt_tip_doc_ci
return number
is
v_tip_documento ba_tip_documentos.cod_tip_documento%type;
-- Busca el código de documento para Cédula de Identidad
BEGIN
  select min( cod_tip_documento )
    into v_tip_documento
    from ba_tip_documentos
   where tip_persona IN( 'F', 'A' )
     and nvl( estado, 'A' ) <> 'I';
  return v_tip_documento;
EXCEPTION
  when others then
    return nvl(v_tip_documento,1);
END;
--obtener datos del primer adicional 
PROCEDURE lp_obt_dat_adicional IS
cursor c_adi is
  select y.nro_documento, y.cod_tip_documento    
    from ta_sol_adicionales x, ba_personas y
   where x.nro_solicitud = v_nro_solicitud
     and x.cod_persona = y.cod_persona
     order by fut_obt_nro_doc_enviar(y.nro_documento, y.cod_persona);
BEGIN
  \*Carga los datos del adicional si tiene*\
  v_lugar := 'lp_dat_adicional';
  ---0. limpio los valores a leer ------------------------------------
  v_nro_doc_adicional := NULL;
  v_tip_doc_adicional     := NULL;

  ---1. Leo la vista de acuerdo a los datos que me pasa --------------
  open c_adi;
  fetch c_adi into v_nro_doc_adicional, v_tip_doc_adicional;
  close c_adi; 
  ---------------------------------------------------------------------
EXCEPTION
  when others then
    NULL;
END lp_obt_dat_adicional;


BEGIN
  --inicio del prg principal--
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;

  --variables a utilizar--
  v_fec_actual       := pag_cal.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
  v_nro_secuencia    := 0;
  v_cod_procesadora  := p_cod_procesadora;

  --Obtener la oficina matriz de la entidad
  --select cod_ofi_matriz into v_cod_oficina from ge_par_generales;

  --borrar datos anteriores si hubiere--
  delete from ta_env_cuentas
   where cod_procesadora = v_cod_procesadora;
  delete from ta_env_tarjetas
   where cod_procesadora = v_cod_procesadora;

  --traer secuencia de envio del historico--
  select nvl(max(a.sec_env_datos),0)+1
    into v_sec_env_datos
    from ta_env_cuentas_his a
   where a.fec_envio = v_fec_actual
     and a.cod_procesadora = v_cod_procesadora;
  
  --obtener el tipo de documento ci
  v_tip_doc_ci := lf_obt_tip_doc_ci;
     
  --cursor principal cuentas--
 \* FOR rc IN c_cuentas LOOP

    v_nro_doc_procesadora := NULL;
    v_nro_doc_cod_procesadora := NULL;
    v_nro_secuencia    := nvl( v_nro_secuencia, 0 ) + 1;
    v_cod_persona      := rc.cod_persona;
    v_nro_solicitud    := rc.nro_solicitud;
    v_cod_modulo       := rc.cod_modulo;
    v_cod_modalidad    := rc.cod_modalidad;
    v_cod_usu_promotor := rc.cod_usu_promotor;
    v_cod_campana      := rc.cod_campana;
    v_cod_oficina      := rc.cod_oficina;
    lp_dir_envio;
    lp_dat_codeudor;
    lp_car_pardinamicos;
    --limpiar variables
    v_nro_doc_adicional := NULL;
    v_tip_doc_adicional := NULL;
    --si el titular es jurídico enviar el nro_doc del primer adicional
    if rc.tip_persona = 'J' then
       lp_obt_dat_adicional;
    end if; 
    --valida nro documento del principal si no es ci, o no cumple formato envía el código de cliente--
    if nvl(v_tip_doc_adicional, rc.cod_tip_documento) <> v_tip_doc_ci or fue_val_campo(nvl(v_nro_doc_adicional,rc.nro_documento), 'N', 9 ) = 'N' then
       v_nro_doc_procesadora := rc.cod_persona * -1;
    end if; 
    --sólo si el codeudor es persona física enviar los datos
    if v_tip_per_codeudor = 'F' then
      --valida documento del codeudor si no es ci, o no cumple formato envía el código de cliente--
      IF v_nro_doc_codeudor IS NOT NULL THEN
        if v_tip_doc_codeudor <> v_tip_doc_ci or fue_val_campo( v_nro_doc_codeudor, 'N', 9 ) = 'N' then
          v_nro_doc_cod_procesadora := v_cod_per_codeudor * -1;
        end if;
      END IF;
    else--no enviar datos del codeudor
      v_nro_doc_codeudor        := null;
      v_nro_doc_cod_procesadora := null;
      v_cod_per_codeudor        := null;
    end if;
    --insertar los datos
    v_sig_nro_cuenta := fut_obt_nro_cuenta(rc.cod_modalidad, rc.cod_tip_tarjeta, rc.tip_afinidad);*\
    BEGIN
    \*  insert into ta_env_cuentas( cod_procesadora,
                                  nro_cuenta,
                                  cod_banco,
                                  cod_sucursal,
                                  nom_usuario,
                                  cod_persona,
                                  nro_documento,
                                  nro_doc_procesadora, --cod_persona si no es ci
                                  direccion,
                                  dir_extendida,
                                  localidad,
                                  cod_zona,
                                  telefono,
                                  cod_encargado,
                                  lim_credito,
                                  cod_for_pago,
                                  cta_bancaria,
                                  cod_mod_pago,
                                  tip_tasa,
                                  tip_comision,
                                  cod_franqueo,
                                  cod_retencion,
                                  nom_codeudor,
                                  nro_doc_codeudor,
                                  nro_doc_cod_procesadora, --cod_persona si no es ci
                                  cod_per_codeudor,
                                  tip_cuenta,
                                  tip_cierre,
                                  fec_novedad,
                                  tip_tarjeta,
                                  cod_afinidad,
                                  cta_vip,
                                  fac_vip,
                                  cod_gas_financiero,
                                  sec_alta,
                                  lim_cuota,
                                  cod_modalidad,
                                  cod_moneda,
                                  estado,
                                  nro_solicitud,
                                  cod_movimiento,
                                  fec_envio,
                                  hor_envio,
                                  sec_env_datos,
                                  es_personalizado,
                                  tas_int_corriente,
                                  tas_int_mora,
                                  pag_minimo,
                                  por_pag_minimo,
                                  int_sob_compras,
                                  tip_persona )
                          values( v_cod_procesadora,
                                  lpad( v_sig_nro_cuenta, 9, '0' ),
                                  v_cod_banco,
                                  v_cod_sucursal,
                                  substr( rc.nom_completo, 1, 30 ),
                                  rc.cod_persona,
                                  nvl(v_nro_doc_adicional, rc.nro_documento), --el doc del adicional si es J el principal
                                  v_nro_doc_procesadora, --cod_persona si no es ci
                                  v_dir_cliente,
                                  v_dir_extendida,
                                  nvl( v_des_ciudad, 'ASUNCION' ),
                                  NULL,
                                  v_tel_cliente,
                                  lpad( v_cod_encargado, 4, '0' ),
                                  nvl( rc.mto_aprobado, 0 ),
                                  decode( rc.deb_automatico, NULL, NULL, 'N', 0, 1 ), --cod_for_pago,
                                  rc.nro_cta_debito, --cta_bancaria,
                                  rc.tip_cob,
                                  rc.tip_tas_financiacion,
                                  rc.tip_com_emision,
                                  rc.franqueo,
                                  v_cod_retencion,
                                  v_nom_codeudor,
                                  v_nro_doc_codeudor,
                                  v_nro_doc_cod_procesadora, --cod_persona si no es ci
                                  v_cod_per_codeudor,
                                  rc.tip_cuenta,
                                  rc.tip_cierre,
                                  v_fec_actual,
                                  rc.cod_tip_tarjeta,
                                  rc.afinidad,
                                  rc.cta_vip,
                                  decode( rc.cta_vip, 'N', '0000', '0000' )\*Cuando Cta Vip = S se debe definir*\,
                                  rc.tip_gas_financiero,
                                  v_nro_secuencia,
                                  0, ---nvl( r_cue.monto, 0 ), -- limite cuotas ya no se usa
                                  r_cue.cod_modalidad,
                                  r_cue.cod_moneda,
                                  'G'\*Datos Generados*\,
                                  rc.nro_solicitud,
                                  rc.tip_generacion,--ACA--
                                  v_fec_actual,
                                  null,
                                  v_sec_env_datos,
                                  rc.cta_personalizada,
                                  0,
                                  0,
                                  0,
                                  0,
                                  0,
                                  rc.tip_persona );*\
            -- actualizo la cuenta en la solicitud
           \* update ta_solicitudes 
               set nro_cuenta = v_sig_nro_cuenta
             where nro_solicitud = rc.nro_solicitud;                                     
    EXCEPTION
      when others then
        IF sqlcode <= -20000 THEN
          RAISE;
        ELSE
          RAISE_APPLICATION_ERROR( -20130, v_lugar || ': insert de TA_ENV_CUENTAS ' || sqlerrm );
        END IF;
    END;*\
    --cursor tarjetas--
   \* FOR r_tar IN c_tarjetas_principal LOOP --sólo físicas
      v_cod_usu_promotor := r_tar.cod_usu_promotor;
      v_cod_campana      := r_tar.cod_campana;
      v_cod_oficina      := r_tar.cod_oficina;
      lp_car_pardinamicos;    
      BEGIN
        insert into ta_env_tarjetas( cod_procesadora,
                                     nro_tarjeta,
                                     nro_cuenta,
                                     nom_usuario,
                                     cod_persona,
                                     nro_documento,
                                     nro_doc_procesadora,  --cod_persona si no es ci
                                     dur_tarjeta,
                                     tip_tarjeta,
                                     ven_tarjeta,
                                     cod_encargado,
                                     cla_tarjeta,
                                     cod_banco,
                                     cod_sucursal,
                                     cod_afinidad,
                                     fec_movimiento,
                                     sec_alta,
                                     cod_movimiento,
                                     nom_embozado,
                                     fec_envio,
                                     hor_envio,
                                     estado,
                                     nro_solicitud,
                                     cod_modalidad,
                                     sec_env_datos )
                             values( v_cod_procesadora,
                                     rpad( '0', 16, '0' ),
                                     lpad( r_tar.nro_cuenta, 9, '0' ),
                                     substr( r_tar.nom_completo, 1, 26 ),
                                     r_tar.cod_persona,
                                     r_tar.nro_documento,
                                     v_nro_doc_procesadora, --cod_persona si no es ci
                                     r_tar.plz_dur_tarjeta,
                                     r_tar.tipo,
                                     to_char( add_months( v_fec_actual, r_tar.plz_dur_tarjeta ), 'MMYY' ),
                                     rpad( '0', 2, '0' ),
                                     r_tar.cod_tip_tarjeta,
                                     v_cod_banco,
                                     v_cod_sucursal,
                                     r_tar.afinidad,
                                     v_fec_actual,
                                     v_nro_secuencia,
                                     r_tar.tip_generacion,--ACA--
                                     r_tar.nom_embozado,
                                     v_fec_actual,
                                     NULL,
                                     'G',
                                     r_tar.nro_solicitud,
                                     v_cod_modalidad,
                                     v_sec_env_datos );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20131, v_lugar || ': insert de TA_ENV_TARJETAS ' || sqlerrm );
          END IF;
      END;
    END LOOP;
    --adicionales (son sólo físicas)
    FOR r_tar IN c_tarjetas_adicional LOOP
      v_nro_doc_adi_procesadora := NULL;
      IF r_tar.cod_tip_documento <> v_tip_doc_ci or fue_val_campo( r_tar.nro_documento, 'N', 9 ) = 'N' THEN
         v_nro_doc_adi_procesadora := r_tar.cod_persona * -1;
      END IF;
      v_cod_usu_promotor := r_tar.cod_usu_promotor;
      v_nro_solicitud    := r_tar.nro_solicitud;
      v_cod_campana      := r_tar.cod_campana;
      v_cod_oficina      := r_tar.cod_oficina;
      lp_car_pardinamicos;   
      --si es el primer adicional de un titular jurídico, se envía como principal       
    --  if r_cue.tip_persona = 'J' and nvl(v_nro_doc_adicional,'0') = r_tar.nro_documento then 
         v_tipo   := '0';
         --v_nombre := r_cue.nom_completo;
      --else
         v_tipo   := r_tar.tipo;
         --v_nombre := r_tar.nom_completo;
    --  end if;
      BEGIN
        insert into ta_env_tarjetas( cod_procesadora,
                                     nro_tarjeta,
                                     nro_cuenta,
                                     nom_usuario,
                                     cod_persona,
                                     nro_documento,
                                     nro_doc_procesadora, --cod_persona si no es ci
                                     dur_tarjeta,
                                     tip_tarjeta,
                                     ven_tarjeta,
                                     cod_encargado,
                                     cla_tarjeta,
                                     cod_banco,
                                     cod_sucursal,
                                     cod_afinidad,
                                     fec_movimiento,
                                     sec_alta,
                                     cod_movimiento,
                                     nom_embozado,
                                     fec_envio,
                                     hor_envio,
                                     estado,
                                     nro_solicitud,
                                     cod_modalidad,
                                     sec_env_datos )
                             values( v_cod_procesadora,
                                     rpad( '0', 16, '0' ),
                                     lpad(r_tar.nro_cuenta, 9, '0' ),
                                     substr( r_tar.nom_completo, 1, 26 ),--substr(v_nombre,1,26),--substr( r_tar.nom_completo, 1, 26 ),
                                     r_tar.cod_persona,
                                     r_tar.nro_documento,
                                     v_nro_doc_adi_procesadora, --cod_persona si no es ci
                                     r_tar.plz_dur_tarjeta,
                                     v_tipo, 
                                     to_char( add_months( v_fec_actual, r_tar.plz_dur_tarjeta ), 'MMYY' ),
                                     rpad( '0', 2, '0' ),
                                     r_tar.cod_tip_tarjeta,
                                     v_cod_banco,
                                     v_cod_sucursal,
                                     r_tar.afinidad,
                                     v_fec_actual,
                                     v_nro_secuencia,
                                     r_tar.tip_generacion,--ACA--
                                     r_tar.nom_embozado,
                                     v_fec_actual,
                                     NULL,
                                     'G',
                                     r_tar.nro_solicitud,
                                     v_cod_modalidad,
                                     v_sec_env_datos );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20132, v_lugar || ': insert de TA_ENV_TARJETAS ' || sqlerrm );
          END IF;
      END;
    END LOOP;*\
    --fin de tarjetas--
  --END LOOP;
  --CURSOR DE CUENTAS MODIFICADAS--
  FOR v IN novedades LOOP
    if length(v.dir_envio) > 35 then
       v_dir_extendida := v.dir_envio;
    else
       v_dir_extendida := null;   
    end if;
    BEGIN
      insert into ta_env_cuentas( cod_procesadora,
                                  nro_cuenta,
                                  cod_banco,
                                  cod_sucursal,
                                  nom_usuario,
                                  cod_persona,
                                  nro_documento,
                                  nro_doc_procesadora,
                                  direccion,
                                  dir_extendida,
                                  localidad,
                                  cod_zona,
                                  telefono,
                                  cod_encargado,
                                  lim_credito,
                                  cod_for_pago,
                                  cta_bancaria,
                                  cod_mod_pago,
                                  tip_tasa,
                                  tip_comision,
                                  cod_franqueo,
                                  cod_retencion,
                                  nom_codeudor,
                                  nro_doc_codeudor,
                                  nro_doc_cod_procesadora,
                                  cod_per_codeudor,
                                  tip_cuenta,
                                  tip_cierre,
                                  fec_novedad,
                                  tip_tarjeta,
                                  cod_afinidad,
                                  cta_vip,
                                  fac_vip,
                                  cod_gas_financiero,
                                  sec_alta,
                                  lim_cuota,
                                  cod_modalidad,
                                  cod_moneda,
                                  estado,
                                  nro_solicitud,
                                  cod_movimiento,
                                  fec_envio,
                                  hor_envio,
                                  sec_env_datos,
                                  es_personalizado,
                                  tas_int_corriente,
                                  tas_int_mora,
                                  pag_minimo,
                                  por_pag_minimo,
                                  int_sob_compras )
                          values( v_cod_procesadora, --cod_procesadora,
                                  v.nro_cuenta, --nro_cuenta,
                                  v_cod_banco, --cod_banco,
                                  NULL, --cod_sucursal,
                                  NULL, --nom_usuario,
                                  NULL, --cod_persona,
                                  NULL, --nro_documento,
                                  NULL, --nro_doc_procesadora,
                                  null, --v.dir_envio, --direccion,
                                  v_dir_extendida, --dir_extendida,
                                  v.localidad, --localidad,
                                  NULL, --cod_zona,
                                  v.tel_principal, --telefono,
                                  NULL, --cod_encargado,
                                  v.lin_credito, --lim_credito,
                                  decode( v.deb_automatico, NULL, NULL, 'N', 0, 1 ), --cod_for_pago,
                                  v.nro_cta_debito, --cta_bancaria,
                                  v.tip_cobro, --cod_mod_pago,
                                  NULL, --tip_tasa,
                                  NULL, --tip_comision,
                                  NULL, --cod_franqueo,
                                  NULL, --cod_retencion,
                                  NULL, --nom_codeudor,
                                  NULL, --nro_doc_codeudor,
                                  NULL, --nro_doc_cod_procesadora,
                                  NULL, --cod_per_codeudor,
                                  NULL, --tip_cuenta,
                                  NULL, --tip_cierre,
                                  v.fecha, --fec_novedad,
                                  NULL, --tip_tarjeta,
                                  NULL, --cod_afinidad,
                                  NULL, --cta_vip,
                                  NULL, --fac_vip,
                                  NULL, --cod_gas_financiero,
                                  NULL, --sec_alta,
                                  0,  -- v.lin_cuotas, --lim_cuota, ya no se usa
                                  NULL, --cod_modalidad,
                                  NULL, --cod_moneda,
                                  'M', --estado ==> Datos Generados
                                  NULL, --nro_solicitud,
                                  'M', --cod_movimiento, --ACA--
                                  v_fec_actual, --fec_envio,
                                  NULL, --hor_envio,
                                  NULL, --sec_env_datos,
                                  NULL, --es_personalizado,
                                  NULL, --tas_int_corriente,
                                  NULL, --tas_int_mora,
                                  NULL, --pag_minimo,
                                  NULL, --por_pag_minimo,
                                  NULL ); --int_sob_compras

    EXCEPTION
      when others then
        IF sqlcode <= -20000 THEN
          RAISE;
        ELSE
          RAISE_APPLICATION_ERROR( -20133, 'No se pudieron insertar los registros para las novedades ' || sqlerrm );
        END IF;
    END;
  END LOOP;
  --- TARJETAS MODIFICADAS ---
  FOR t IN tar_modificadas LOOP
    \*v_cod_usu_promotor := r.cod_usu_promotor;
    v_cod_campana      := r.cod_campana;
    v_cod_oficina      := r.cod_oficina;
    v_nro_cuenta       := r.nro_cuenta;
    lp_car_pardinamicos;        *\

    v_nro_doc_procesadora := NULL;
    --verificar nro_documento
    IF t.cod_tip_documento <> v_tip_doc_ci or fue_val_campo( t.nro_documento, 'N', 9 ) = 'N' THEN
       v_nro_doc_procesadora := t.cod_persona * -1;
    END IF;

    BEGIN
        insert into ta_env_tarjetas( cod_procesadora,
                                     nro_tarjeta,
                                     nro_cuenta,
                                     nom_usuario,
                                     cod_persona,
                                     nro_documento,
                                     nro_doc_procesadora,
                                     dur_tarjeta,
                                     tip_tarjeta,
                                     ven_tarjeta,
                                     cod_encargado,
                                     cla_tarjeta,
                                     cod_banco,
                                     cod_sucursal,
                                     cod_afinidad,
                                     fec_movimiento,
                                     sec_alta,
                                     cod_movimiento,
                                     nom_embozado,
                                     fec_envio,
                                     hor_envio,
                                     estado,
                                     nro_solicitud,
                                     cod_modalidad,
                                     sec_env_datos )
                             values( v_cod_procesadora,
                                     t.nro_tarjeta,
                                     lpad(t.nro_cuenta,9,'0'),
                                     null,--substr( r.nom_usuario, 1, 26 ),
                                     t.cod_persona,
                                     t.nro_documento,
                                     v_nro_doc_procesadora,
                                     null,--r.plz_dur_tarjeta,
                                     null,--r.tipo,
                                     null,--to_char( add_months( v_fec_actual, r.plz_dur_tarjeta ), 'MMYY' ),
                                     null,
                                     null,--r.cod_tip_tarjeta,
                                     null,--v_cod_banco,
                                     null,--v_cod_sucursal,
                                     null,
                                     v_fec_actual,--fec_movimiento
                                     null,
                                     'M',--ACA--
                                     null,
                                     v_fec_actual,--fec_envio
                                     null,
                                     'M',
                                     t.nro_solicitud,
                                     null,--v_cod_modalidad,
                                     null );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20182, v_lugar || ': insert de TA_ENV_TARJETAS ' || sqlerrm );
          END IF;
      END;
  END LOOP;
  -- Cursor de Tarjetas Titulares enviadas. Envío de Adicionales
  FOR r_cue IN c_cue_enviadas LOOP
    v_nro_doc_procesadora := NULL;
    v_nro_doc_cod_procesadora := NULL;
    v_nro_secuencia    := nvl( v_nro_secuencia, 0 ) + 1;
    v_cod_persona      := r_cue.cod_persona;
    v_nro_solicitud    := r_cue.nro_solicitud;
    v_cod_modulo       := r_cue.cod_modulo;
    v_cod_modalidad    := r_cue.cod_modalidad;
    v_cod_usu_promotor := r_cue.cod_usu_promotor;
    v_cod_campana      := r_cue.cod_campana;
    v_cod_oficina      := r_cue.cod_oficina;
    lp_dir_envio;
    lp_dat_codeudor;
    lp_car_pardinamicos;
    v_existe := 'N';
    FOR r_tar IN c_tarjetas_adicional LOOP
      v_existe := 'S'; -- si existen adicionales a enviar
      exit;
    END LOOP;
    FOR r IN no_renovacion LOOP  
      v_existe := 'S'; --existen no renovación
      exit;
    END LOOP;
    --limpiar variables
    v_nro_doc_adicional := NULL;
    v_tip_doc_adicional := NULL;
    --si ya se envió el principal, no hace falta enviar
    --si el titular es jurídico enviar el nro_doc del primer adicional
    if r_cue.tip_persona = 'J' then
       lp_obt_dat_adicional;
    end if; 
    --valida nro documento del principal--
    if nvl(v_tip_doc_adicional,r_cue.cod_tip_documento) <> v_tip_doc_ci or fue_val_campo(nvl(v_nro_doc_adicional,r_cue.nro_documento), 'N', 9 ) = 'N' THEN
       v_nro_doc_procesadora := r_cue.cod_persona * -1;
    END IF;
    --sólo si el codeudor es persona física enviar los datos
    if v_tip_per_codeudor = 'F' then
      --valida documento del codeudor si no es ci, o no cumple formato envía el código de cliente--
      IF v_nro_doc_codeudor IS NOT NULL THEN
        if v_tip_doc_codeudor <> v_tip_doc_ci or fue_val_campo( v_nro_doc_codeudor, 'N', 9 ) = 'N' then
          v_nro_doc_cod_procesadora := v_cod_per_codeudor * -1;
        end if;
      END IF;
    else--no enviar datos del codeudor
      v_nro_doc_codeudor        := null;
      v_nro_doc_cod_procesadora := null;
      v_cod_per_codeudor        := null;
    end if;
    IF v_existe = 'S' THEN
      BEGIN
        insert into ta_env_cuentas( cod_procesadora,
                                    nro_cuenta,
                                    cod_banco,
                                    cod_sucursal,
                                    nom_usuario,
                                    cod_persona,
                                    nro_documento,
                                    nro_doc_procesadora, --cod_persona si no es ci
                                    direccion,
                                    dir_extendida,
                                    localidad,
                                    cod_zona,
                                    telefono,
                                    cod_encargado,
                                    lim_credito,
                                    cod_for_pago,
                                    cta_bancaria,
                                    cod_mod_pago,
                                    tip_tasa,
                                    tip_comision,
                                    cod_franqueo,
                                    cod_retencion,
                                    nom_codeudor,
                                    nro_doc_codeudor,
                                    nro_doc_cod_procesadora, --cod_persona si no es ci
                                    cod_per_codeudor,
                                    tip_cuenta,
                                    tip_cierre,
                                    fec_novedad,
                                    tip_tarjeta,
                                    cod_afinidad,
                                    cta_vip,
                                    fac_vip,
                                    cod_gas_financiero,
                                    sec_alta,
                                    lim_cuota,
                                    cod_modalidad,
                                    cod_moneda,
                                    estado,
                                    nro_solicitud,
                                    cod_movimiento,
                                    fec_envio,
                                    hor_envio,
                                    sec_env_datos,
                                    es_personalizado,
                                    tas_int_corriente,
                                    tas_int_mora,
                                    pag_minimo,
                                    por_pag_minimo,
                                    int_sob_compras,
                                    tip_persona )
                            values( v_cod_procesadora,
                                    lpad( r_cue.nro_cta_actual,9 , '0' ),--rpad( '0', 9, '0' ),
                                    v_cod_banco,
                                    v_cod_sucursal,
                                    substr( r_cue.nom_completo, 1, 30 ),
                                    r_cue.cod_persona,
                                    nvl(v_nro_doc_adicional, r_cue.nro_documento), --el doc del adicional si es J el principal
                                    v_nro_doc_procesadora, --cod_persona si no es ci
                                    v_dir_cliente,
                                    v_dir_extendida,
                                    nvl( v_des_ciudad, 'ASUNCION' ),
                                    NULL,
                                    v_tel_cliente,
                                    lpad( v_cod_encargado, 4, '0' ),
                                    nvl( r_cue.mto_aprobado, 0 ),
                                    decode( r_cue.deb_automatico, NULL, NULL, 'N', 0, 1 ), --cod_for_pago,
                                    r_cue.nro_cta_debito, --cta_bancaria,
                                    r_cue.tip_cob,
                                    r_cue.tip_tas_financiacion,
                                    r_cue.tip_com_emision,
                                    r_cue.franqueo,
                                    v_cod_retencion,
                                    v_nom_codeudor,
                                    v_nro_doc_codeudor,
                                    nvl(v_nro_doc_codeudor,v_nro_doc_cod_procesadora), --cod_persona si no es ci
                                    v_cod_per_codeudor,
                                    r_cue.tip_cuenta,
                                    r_cue.tip_cierre,
                                    v_fec_actual,
                                    r_cue.cod_tip_tarjeta,
                                    r_cue.afinidad,
                                    r_cue.cta_vip,
                                    decode( r_cue.cta_vip, 'N', '0000', '0000' )\*Cuando Cta Vip = S se debe definir*\,
                                    r_cue.tip_gas_financiero,
                                    v_nro_secuencia,
                                    0, -- nvl( r_cue.monto, 0 ), ya no se usa limite en cuotas
                                    r_cue.cod_modalidad,
                                    r_cue.cod_moneda,
                                    'X',--'G'\*Datos Generados*\, para q no vuelva a enviar cuentas enviadas
                                    r_cue.nro_solicitud,
                                    'X',--r_cue.tip_generacion, --ACA--
                                    v_fec_actual,
                                    null,
                                    v_sec_env_datos,
                                    r_cue.cta_personalizada,
                                    0,
                                    0,
                                    0,
                                    0,
                                    0,
                                    r_cue.tip_persona );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20130, v_lugar || ': insert de TA_ENV_CUENTAS ' || sqlerrm );
          END IF;
      END;

      FOR r_tar IN c_tarjetas_adicional LOOP
        v_nro_doc_adi_procesadora := NULL;
        IF r_tar.cod_tip_documento <> v_tip_doc_ci or fue_val_campo( r_tar.nro_documento, 'N', 9 ) = 'N' THEN
           v_nro_doc_adi_procesadora := r_tar.cod_persona * -1;
        END IF;
        BEGIN
          insert into ta_env_tarjetas( cod_procesadora,
                                       nro_tarjeta,
                                       nro_cuenta,
                                       nom_usuario,
                                       cod_persona,
                                       nro_documento,
                                       nro_doc_procesadora, --cod_persona si no es ci
                                       dur_tarjeta,
                                       tip_tarjeta,
                                       ven_tarjeta,
                                       cod_encargado,
                                       cla_tarjeta,
                                       cod_banco,
                                       cod_sucursal,
                                       cod_afinidad,
                                       fec_movimiento,
                                       sec_alta,
                                       cod_movimiento,
                                       nom_embozado,
                                       fec_envio,
                                       hor_envio,
                                       estado,
                                       nro_solicitud,
                                       cod_modalidad,
                                       sec_env_datos )
                               values( v_cod_procesadora,
                                       rpad( '0', 16, '0' ),
                                       lpad( r_cue.nro_cuenta,9 , '0' ),--rpad( '0', 9, '0' ),
                                       substr( r_tar.nom_completo, 1, 26 ),
                                       r_tar.cod_persona,
                                       r_tar.nro_documento,
                                       v_nro_doc_adi_procesadora, --cod_persona si no es ci
                                       r_tar.plz_dur_tarjeta,
                                       r_tar.tipo,
                                       to_char( add_months( v_fec_actual, r_tar.plz_dur_tarjeta ), 'MMYY' ),
                                       rpad( '0', 2, '0' ),
                                       r_tar.cod_tip_tarjeta,
                                       v_cod_banco,
                                       v_cod_sucursal,
                                       r_tar.afinidad,
                                       v_fec_actual,
                                       v_nro_secuencia,
                                       r_tar.tip_generacion,--ACA--
                                       r_tar.nom_embozado,
                                       v_fec_actual,
                                       NULL,
                                       'G',
                                       r_tar.nro_solicitud,
                                       v_cod_modalidad,
                                       v_sec_env_datos );
        EXCEPTION
          when others then
            IF sqlcode <= -20000 THEN
              RAISE;
            ELSE
              RAISE_APPLICATION_ERROR( -20132, v_lugar || ': insert de TA_ENV_TARJETAS ' || sqlerrm );
            END IF;
        END;
      END LOOP;
   END IF;
  END LOOP; --Fin de Tarjetas Titulares Enviadas. Envío de Adicionales--
  --- TARJETAS NO RENOVADAS ---
  FOR r IN no_renovacion LOOP
    v_cod_usu_promotor := r.cod_usu_promotor;
    v_cod_campana      := r.cod_campana;
    v_cod_oficina      := r.cod_oficina;
    v_nro_cuenta       := r.nro_cuenta;
    lp_car_pardinamicos;        

    v_nro_doc_procesadora := NULL;
    --verificar nro_documento
    IF r.cod_tip_documento <> v_tip_doc_ci or fue_val_campo( r.nro_documento, 'N', 9 ) = 'N' THEN
       v_nro_doc_procesadora := r.cod_persona * -1;
    END IF;

    BEGIN
        insert into ta_env_tarjetas( cod_procesadora,
                                     nro_tarjeta,
                                     nro_cuenta,
                                     nom_usuario,
                                     cod_persona,
                                     nro_documento,
                                     nro_doc_procesadora,
                                     dur_tarjeta,
                                     tip_tarjeta,
                                     ven_tarjeta,
                                     cod_encargado,
                                     cla_tarjeta,
                                     cod_banco,
                                     cod_sucursal,
                                     cod_afinidad,
                                     fec_movimiento,
                                     sec_alta,
                                     cod_movimiento,
                                     nom_embozado,
                                     fec_envio,
                                     hor_envio,
                                     estado,
                                     nro_solicitud,
                                     cod_modalidad,
                                     sec_env_datos )
                             values( v_cod_procesadora,
                                     r.nro_tarjeta,
                                     lpad(r.nro_cuenta,9,'0'),
                                     substr( r.nom_usuario, 1, 26 ),
                                     r.cod_persona,
                                     r.nro_documento,
                                     v_nro_doc_procesadora,
                                     r.plz_dur_tarjeta,
                                     r.tipo,
                                     null,--to_char( add_months( v_fec_actual, r.plz_dur_tarjeta ), 'MMYY' ),
                                     null,
                                     null,--r.cod_tip_tarjeta,
                                     v_cod_banco,
                                     v_cod_sucursal,
                                     null,
                                     v_fec_actual,
                                     null,
                                     null,--ACA--
                                     null,
                                     v_fec_actual,
                                     null,
                                     'E',
                                     null,
                                     v_cod_modalidad,
                                     null );
      EXCEPTION
        when others then
          IF sqlcode <= -20000 THEN
            RAISE;
          ELSE
            RAISE_APPLICATION_ERROR( -20132, v_lugar || ': insert de TA_ENV_TARJETAS ' || sqlerrm );
          END IF;
      END;
  END LOOP;
  -----------------------------
EXCEPTION
  when OTHERS Then
    IF sqlcode <= -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR( -20134, sqlerrm || ' / ' || v_lugar || '-' || v_nro_solicitud ||
                                       '-' || v_cod_modalidad );
    END IF;
END;
*/
/

