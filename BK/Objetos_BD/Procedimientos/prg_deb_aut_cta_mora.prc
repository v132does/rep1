CREATE OR REPLACE PROCEDURE IT.PRG_DEB_AUT_CTA_MORA
     IS

  -- OMM -PCC- 20/09/2013 Proceso que actualiza las cuentas de Prestamos y Tarjetas
  --          con debito automático de cuentas de pago nomina del Ente en Fuga
v_cod_ente     ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_ENT_FUGA') ;
v_cta_debito   ge_cta_clientes.nro_cuenta%type ;
v_can_tarjeta   number(10) := 0 ;
v_can_prestamo  number(10) := 0 ;

  Cursor Cta_Activa is
      Select c.cod_persona, c.nro_cuenta, c.cod_modulo
        from ta_cta_tarjetas t, ge_cta_clientes c
        where c.nro_cuenta    = t.nro_cuenta
          and c.cod_modalidad = t.cod_modalidad
          and c.relacion = 'P'
          and t.deb_automatico <> 'S'
          and t.estado NOT IN ('C')
          and c.cod_persona in (Select distinct a.cod_persona
                                from ge_cta_clientes a, cc_cta_corrientes cc
                                  where a.nro_cuenta    = cc.nro_cuenta
                                    and a.cod_modalidad = cc.cod_modalidad
                                    and cc.cod_ente in (v_cod_ente)
                                    and cc.estado <> 'C'
                                    and a.relacion = 'P'
                                union
                                Select distinct a.cod_persona
                                  from ge_cta_clientes a, ah_cta_vistas ah
                                  where a.nro_cuenta    = ah.nro_cuenta
                                    and a.cod_modalidad = ah.cod_modalidad
                                    and ah.cod_sub_modalidad <> 6 -- Se excluye Aguinaldo
                                    and ah.cod_ente in (v_cod_ente)
                                    and ah.estado not in ('C', 'P')
                                    and a.relacion = 'P' )

      union all

      Select c.cod_persona, c.nro_cuenta, c.cod_modulo
        from pr_cta_prestamos p, ge_cta_clientes c
        where c.nro_cuenta    = p.nro_cuenta
          and c.cod_modalidad = p.cod_modalidad
          and c.relacion = 'P'
          and p.cob_automatico <> 'S'
          and p.estado in ('C', 'V', 'M', 'G')
          and c.cod_persona in (Select distinct a.cod_persona
                                from ge_cta_clientes a, cc_cta_corrientes cc
                                  where a.nro_cuenta    = cc.nro_cuenta
                                    and a.cod_modalidad = cc.cod_modalidad
                                    and cc.cod_ente in (v_cod_ente)
                                    and cc.estado <> 'C'
                                    and a.relacion = 'P'
                                union
                                Select distinct a.cod_persona
                                  from ge_cta_clientes a, ah_cta_vistas ah
                                  where a.nro_cuenta    = ah.nro_cuenta
                                    and a.cod_modalidad = ah.cod_modalidad
                                    and ah.cod_sub_modalidad <> 6 -- Se excluye Aguinaldo
                                    and ah.cod_ente in (v_cod_ente)
                                    and ah.estado not in ('C', 'P')
                                    and a.relacion = 'P' ) ;


BEGIN

   Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1 ;
         pae_cnf.G_PROGRAMA := 'GPPROFIN'; end ;

   For i in Cta_Activa loop
      Begin
         Select cc.nro_cuenta
           into v_cta_debito
          from ge_cta_clientes a, cc_cta_corrientes cc
            where a.nro_cuenta    = cc.nro_cuenta
              and a.cod_modalidad = cc.cod_modalidad
              and cc.cod_ente in (v_cod_ente)
              and cc.estado <> 'C'
              and a.relacion = 'P'
              and a.cod_persona = i.cod_persona ;
      EXCEPTION
         WHEN no_data_found THEN
            Begin
              Select a.cod_persona
                into v_cta_debito
                from ge_cta_clientes a, ah_cta_vistas ah
                where a.nro_cuenta    = ah.nro_cuenta
                  and a.cod_modalidad = ah.cod_modalidad
                  and ah.cod_sub_modalidad <> 6 -- Se excluye Aguinaldo
                  and ah.cod_ente in (v_cod_ente)
                  and ah.estado not in ('C', 'P')
                  and a.relacion = 'P'
                  and a.cod_persona = i.cod_persona ;
            EXCEPTION
               WHEN others THEN
                 prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), fug_obt_pardinamico('PAG_NOM_LIN_SOB_MAIL'),
            /*Asunto*/   'Error al tratar de buscar Cta Ahorro a Relacionar',
            /*Detalle*/  'Error al tratar de Procesar el Cliente: '|| i.cod_persona || chr(13)||
                         'Para Asociar a la Cuenta : '||  i.nro_cuenta|| chr(13)||
                         'del Modulo: '|| i.cod_modulo ) ;
            end;

          WHEN others THEN
              prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), fug_obt_pardinamico('PAG_NOM_LIN_SOB_MAIL'),
            /*Asunto*/   'Error al tratar de buscar Cta Corriente a Relacionar',
            /*Detalle*/  'Error al tratar de Procesar el Cliente: '|| i.cod_persona || chr(13)||
                         'Para Asociar a la Cuenta : '||  i.nro_cuenta|| chr(13)||
                         'del Modulo: '|| i.cod_modulo ) ;
      END;

       -- Actualiza Cuenta de Tarjeta
       if i.cod_modulo = 5 and v_cta_debito is not null then
          update ta_cta_tarjetas t
             set t.nro_cta_debito = v_cta_debito,
                 t.deb_automatico = 'S',
                 t.tip_cobro      = 'M' -- Minimo (Deuda en mora)
           where t.nro_cuenta = i.nro_cuenta
             and t.cod_modulo = i.cod_modulo ;

           v_can_tarjeta := v_can_tarjeta + 1 ;
        end if ;
        -- Actualiza Cuenta de Prestamo
        if i.cod_modulo = 6 and v_cta_debito is not null then
          update pr_cta_prestamos p
             set p.nro_cta_debito = v_cta_debito,
                 p.cob_automatico = 'S'
           where p.nro_cuenta = i.nro_cuenta
             and p.cod_modulo = i.cod_modulo ;

           v_can_prestamo := v_can_prestamo + 1 ;
        end if ;

        v_cta_debito := null ;
   End loop ;

   -- Envia mail para avisar de la finalización correcta del procedimiento
   prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), fug_obt_pardinamico('PAG_NOM_LIN_SOB_MAIL'),
    /*Asunto*/   'Finalización del Proceso de Adhesion automática de Cuenta',
    /*Detalle*/  'Finalización del Proceso de Adhesion automática de Cuenta para ente nomina : '|| v_cod_ente || chr(13)||
                 'Cantidad de Tarjetas Vinculadas : '||  v_can_tarjeta|| chr(13)||
                 'Cantidad de Prestamos Vinculados : '|| v_can_prestamo|| chr(13)||
                 'Saludos ' ) ;

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'PRG_DEB_AUT_CTA_MORA. ' || SQLERRM);
END;
/

