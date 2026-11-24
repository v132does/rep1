create or replace function it.FUP_OBT_MTO_LIN_APROBADA(P_COD_PERSONA IN VARCHAR2, P_COD_MONEDA IN VARCHAR2) return number is
  v_mto_limite pr_lineas.monto%type;
begin
  Select pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, monto)
    into v_mto_limite
    from pr_lineas
   where cod_persona = p_cod_persona
     and estado = 'A';
  return(v_mto_limite);
Exception
  When NO_DATA_FOUND then
       Return 0;
  When TOO_MANY_ROWS then
      Select sum(pag_gen.FU_CON_MON_A_MONEDA(cod_moneda, p_cod_moneda, monto))
        into v_mto_limite
        from pr_lineas
       where cod_persona = p_cod_persona
         and estado = 'A';
      Return v_mto_limite;
  When OTHERS then
     If sqlcode <= -20000 then
        raise;
     Else
        Raise_application_error(-20000, 'Error al obtener monto de limite aprobado '||sqlerrm);
     End if;
end FUP_OBT_MTO_LIN_APROBADA;
/

