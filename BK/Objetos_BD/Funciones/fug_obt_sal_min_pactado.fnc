CREATE OR REPLACE FUNCTION IT.FUG_OBT_SAL_MIN_PACTADO
(P_COD_MONEDA IN  VARCHAR2
,P_COD_PERSONA IN VARCHAR2
,P_COD_MODULO  IN NUMBER DEFAULT NULL
,P_COD_MODALIDAD IN  NUMBER DEFAULT NULL
,P_COD_OFICINA IN  NUMBER DEFAULT NULL
,P_COD_SUB_MODALIDAD IN VARCHAR2 DEFAULT NULL)
RETURN  INTEGER
IS
v_sal_minimo  cc_cta_combinadas.sal_minimo%type;
Begin
If  FUG_ES_EMPLEADO(p_cod_persona) = 'S' then
v_sal_minimo :=  FUG_OBT_PARDINAMICO('SAL_MIN_PAC_EMPLEADO',p_cod_modulo,p_cod_modalidad,p_cod_moneda,p_cod_oficina,p_cod_sub_modalidad);
else
v_sal_minimo  := FUG_OBT_PARDINAMICO('SAL_MIN_PACTADO',p_cod_modulo,p_cod_modalidad,p_cod_moneda,p_cod_oficina,p_cod_sub_modalidad);
End  if;
return v_sal_minimo;
exception
when  others then
If sqlcode <= -20000  then
raise;
else
raise_application_error(-20000,'Al obtener el saldo mínimo pactado '||sqlerrm);
End  if;
end;
/

