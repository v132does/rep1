create or replace procedure it.PRT_ACT_TAR_MIGRADAS is
 cursor ta_sol is
--- el campo cta.cod_usu_promotor nvl clt.cod_Usu_oficial
--- fecha de aprobacion nvl cta.fec_apertura
        select tar.cod_persona      , cta.cod_oficina         , cta.cod_modulo     , cta.tip_cobro      ,
               cta.cod_modalidad    , nvl(cta.cod_usu_promotor, clt.cod_usu_oficial) cod_usu_promotor   ,
               NVL(cta.fec_solicitud,trunc(sysdate)) fec_solicitud   , clt.cod_usu_oficial     , cta.fec_apertura   , cta.tas_adelanto   ,
               cta.cod_causa        , cta.deb_automatico      , cta.nro_cta_debito , cta.por_pag_minimo ,
               tar.nom_embozar      , cta.lin_credito         , 'TIA' cod_estado   , cta.cod_moneda     ,
               cta.tas_financiacion , cta.tas_mora            , cta.mto_min_pago   , cta.cod_canal      ,
               tar.tip_envio        , tar.referencia          , cta.nro_linea      , cta.nro_cuenta     ,
               cta.cod_campana
          from ge_clientes clt    ,
               ge_cta_clientes cli,
               ta_cta_tarjetas cta,
               ta_tarjetas     tar
         where clt.cod_persona = cli.cod_persona
           and cta.nro_cuenta  = tar.nro_cuenta
           and cta.nro_cuenta  = cli.nro_cuenta
           and cli.relacion    = 'P'
           AND cta.estado      = 'N' --solo activas
           and cta.nro_solicitud is null;

 v_nro_solicitud ta_solicitudes.nro_solicitud%type;
 v_existe varchar2(1);
begin
  for t in ta_sol loop

   select s_nro_solicitud.nextval
     into v_nro_solicitud
     from dual;
    --**************************---
    begin
      insert into ta_solicitudes
          (nro_solicitud   , cod_persona     , cod_oficina     , cod_modulo      ,
           cod_modalidad   , cod_usu_promotor, fec_solicitud   , cod_usu_oficial ,
           fec_aprobacion  , cod_causa       , deb_automatico  , nro_cta_debito  ,
           tip_cobro       , nom_embozado    , lin_sugerida    , monto           ,
           puntaje         , cod_estado      , cod_est_sugerido, tas_int_adelanto,
           tas_financiacion, tas_mora        , mto_min_pago    , por_pag_minimo  ,
           tip_envio       , referencia      , usu_insercion   , fec_insercion   ,
           usu_modificacion, fec_modificacion, nro_linea       , observacion     ,
           cod_moneda      , cod_campana     , cod_canal       , mto_aprobado    ,
           niv_aprobacion  , nro_acta        , nro_cuenta)
      values
          (v_nro_solicitud   , t.cod_persona     , t.cod_oficina   , t.cod_modulo     ,
           t.cod_modalidad   , t.cod_usu_promotor, t.fec_solicitud , t.cod_usu_oficial,
           t.fec_apertura    , t.cod_causa       , t.deb_automatico, t.nro_cta_debito ,
           t.tip_cobro       , t.nom_embozar     , null            , t.lin_credito    ,
           null              , t.cod_estado      , null            , t.tas_adelanto   ,
           t.tas_financiacion, t.tas_mora        , t.mto_min_pago  , t.por_pag_minimo ,
           t.tip_envio       , t.referencia      , user            , sysdate          ,
           user              , sysdate           , t.nro_linea     , null             ,
           t.cod_moneda      , t.cod_campana     , t.cod_canal     , t.lin_credito    ,
           null              , null              , t.nro_cuenta);
    exception
      when others then
        raise_application_error(-20001,'Ocurrio un error al insertar datos en TA_SOLICITUDES '||sqlerrm);
    end;
    --**************************---
    select count(*)
      into v_existe
      from ta_solicitudes sol
     where sol.nro_solicitud = v_nro_solicitud;


    begin
      update ta_cta_tarjetas cta
         set cta.nro_solicitud = v_nro_solicitud
       where cta.nro_cuenta    = t.nro_cuenta;
    exception
      when others then
        raise_application_error(-20002,'Ocurrio un error en la modificacion de datos en TA_CTA_TARJETAS '||sqlerrm);
    end;
    --**************************---
    begin
       insert into ta_sol_adicionales
              (nro_solicitud   , cod_persona     , cod_estado   , fec_aprobacion  ,
               fec_ingreso     , cod_causa       , nom_embozado , cod_usu_autoriza,
               cod_usu_promotor, cod_usu_oficial , usu_insercion, fec_insercion   ,
               usu_modificacion, fec_modificacion, observacion  , niv_aprobacion  ,
               nro_acta        )
        select v_nro_solicitud     , tar.cod_persona   , t.cod_estado     , t.fec_apertura,
               sysdate             , tar.cod_causa     , tar.nom_embozar  , null          ,
               cta.cod_usu_promotor, t.cod_usu_oficial , user             , sysdate       ,
               user                , sysdate           , null             , null          ,
               null
          from ta_cta_tarjetas cta,
               ta_tarjetas     tar,
               ge_cta_clientes cli
         where cta.nro_cuenta    = tar.nro_cuenta
           and cta.nro_cuenta    = cli.nro_cuenta
           and cli.relacion      = 'A'
           and not exists (Select '1'
                             from ta_sol_adicionales adi
                            where adi.nro_solicitud = v_nro_solicitud
                              and adi.cod_persona   = cli.cod_persona)
           AND tar.fec_emision = (SELECT  MIN(fec_emision)
                                    FROM  ta_tarjetas
                                   WHERE nro_cuenta =  tar.nro_cuenta
                                     AND cod_persona =  tar.cod_persona);
    exception
      when dup_val_on_index then 
      null;
      when others then
        raise_application_error(-20003,'Ocurrio un error al insertar datos en TA_SOL_ADICIONALES '||sqlerrm);
    end;
    --**************************---
    begin
      insert into ta_sol_garantias
            (nro_solicitud  , nro_garantia , cod_garantia    , mto_aplicado    ,
             usu_insercion  , fec_insercion, usu_modificacion, fec_modificacion)
      select v_nro_solicitud,  null        , 1               , gar.mto_aplicado,
             user           ,  sysdate     , user            , sysdate
        from ta_cta_garantias gar
       where gar.nro_cuenta = t.nro_cuenta;
    exception
      when dup_val_on_index then 
      null;
      when others then
         raise_application_error(-20004,'Ocurrio un error al insertar datos en TA_SOL_GARANTIAS '||sqlerrm);
    end;

   end loop;

end PRT_ACT_TAR_MIGRADAS;
/

