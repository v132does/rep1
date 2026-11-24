CREATE OR REPLACE PROCEDURE IT.PRG_ACT_LIN_SOB_ENTE
         IS

  -- OMM -PCC- 20/09/2013 Proceso que actualiza el monto de la linea de sobregiro al minimo utilizado 
  -- o en caso de no estar utilizado baja a 1Gs
  v_cod_ente    ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_ENT_FUGA') ;

  Cursor cta_ente is
     Select c.nro_cuenta Nro_Cuenta,
       nvl(c.SAL_TOTAL,0)-nvl(c.SAL_RETENIDO,0)-nvl(c.SAL_BLOQUEADO,0)-nvl(c.MTO_DEB_PENDIENTES,0)+nvl(c.MTO_CRE_PENDIENTES,0) Sal_Disponible,
       s.monto
     from cc_cta_corrientes c, cc_lin_sobregiros s
     where c.cod_ente IN (v_cod_ente)
       and c.nro_cuenta = s.nro_cuenta
       and s.estado = 'A' ;

  v_mto_linea    cc_lin_sobregiros.monto%type := 0 ;
  v_cantidad     number(10) := 0;

BEGIN

   Begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1 ; end ;

   For i in cta_ente loop
      if i.Sal_Disponible < 0 and abs(i.sal_disponible) < i.monto then
         v_mto_linea := abs(i.Sal_Disponible);
      elsif i.Sal_Disponible < 0 and abs(i.sal_disponible) > i.monto then
         v_mto_linea := i.monto ;
      else
         v_mto_linea := 1 ;
      end if ;

      Begin
         Update cc_lin_sobregiros cc
            set cc.monto = v_mto_linea
         where cc.nro_cuenta = i.Nro_Cuenta
           and cc.estado     = 'A' ;
      Exception
         When others then
            v_mto_linea := 0 ;
            prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), fug_obt_pardinamico('PAG_NOM_LIN_SOB_MAIL'),
            /*Asunto*/   'Error al intentar actualizar Linea de Sobregiro',
            /*Detalle*/  'Error al tratar de Procesar el Nro de Cuenta: '|| i.Nro_Cuenta || chr(13)||
                         'Con el monto: '||  v_mto_linea) ;
      End ;
      v_cantidad := v_cantidad + 1 ;
   End loop ;
   prg_env_mail(fug_obt_pardinamico('CAM_MAR_DIR_MAIL'), fug_obt_pardinamico('PAG_NOM_LIN_SOB_MAIL'),
            /*Asunto*/   'Finalizo la actualización de Linea de Sobregiro',
            /*Detalle*/  'Se finalizaron la actualización de : '|| v_cantidad||'Registros. ') ;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000, 'PRG_ACT_LIN_SOB_ENTE. ' || SQLERRM);
END;
/

