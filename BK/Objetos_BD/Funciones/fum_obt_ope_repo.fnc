CREATE OR REPLACE Function IT.Fum_Obt_Ope_Repo(p_cod_modulo     In md_tip_operaciones.cod_modulo%Type,
                                            p_cod_modalidad  In md_tip_operaciones.cod_mad_operacion%Type,
                                            p_activo         In md_tip_operaciones.activo%Type,
                                            p_tip_operacion  In md_tip_operaciones.tip_operacion%Type Default Null)
  Return Varchar2 Is
  
  v_valor  Varchar2(1);
-- CNFREINT-104 --
Begin
  If p_tip_operacion Is Not Null Then

     Begin
      Select 'S'
        Into v_valor
        from MD_TIP_OPERACIONES o
       Where o.cod_modulo = p_cod_modulo
         And o.cod_mad_operacion = p_cod_modalidad
         And o.activo = p_activo
         And o.tip_operacion = p_tip_operacion;
      Exception
        When no_data_found Then
          v_valor :=  'N';
      End;

  Else

     Begin
      select 'S'
        Into v_valor
        from MD_TIP_OPERACIONES o
       Where o.cod_modulo = p_cod_modulo
         And o.cod_mad_operacion = p_cod_modalidad
         And o.activo = p_activo;
     Exception
       When no_data_found Then
         v_valor := 'N';
     End;

   End If;

   Return (v_valor);

End;
/

