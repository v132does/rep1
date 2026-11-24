CREATE OR REPLACE FUNCTION IT.FUC_OBT_SOB_AUTORIZADO
 (P_CUENTA IN VARCHAR2
 )
 RETURN varchar2
 IS
 --Creado por : Julio Leguizamon
 --Fecha 			: 17/05/2006
 --Objetivo		: funcion que recibe como argumento un numero de cuenta corriente y devuelve si la misma
 --tiene sobregiro no autorizado

v_result           varchar2(1);--Valores posibles S/N
v_sal_total        cc_cta_corrientes.sal_total%type;
v_monto            cc_lin_sobregiros.monto%type;
begin
  --Obtener monto de sobregiro
  select nvl(sal_total-sal_retenido,0)
  into v_sal_total
  from cc_cta_corrientes
  where nro_cuenta = p_cuenta;
  
  select nvl(sum(monto),0)
  into v_monto
  from cc_lin_sobregiros
  where estado = 'A'
  and nro_cuenta = p_cuenta;

  if v_sal_total < 0 then--tiene sobregiro
    if v_sal_total*-1 > v_monto then
       v_result := 'S';--monto sobregirado supera a las lineas de sobregiros
    else
       v_result := 'N';--monto sobregirado NO supera a las lineas de sobregiros
    end if;
  else--no tiene sobregiro
     v_result := 'N';
  end if;
  return v_result;
End;
/

