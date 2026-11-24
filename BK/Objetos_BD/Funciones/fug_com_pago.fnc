create or replace function it.fug_com_pago
(P_COD_PERSONA IN VARCHAR2) return varchar2 is
  Result varchar2(1) := 'N';  -- no registra
cursor ctas is  
select max_atraso, pro_atraso, dia_atraso
  from ge_cuentas a, ge_cta_clientes b
 where a.nro_cuenta = b.nro_cuenta
   and b.relacion = 'P'
   and b.cod_persona = p_cod_persona
   and a.cod_modulo in (4,5,6,8)  -- solo cuentas pasivas
 order by nvl(fec_vencimiento,sysdate) desc;
 cc ctas%rowtype;
begin
  -- Evalua el tipo de atraso de la ultima operacion de una persona
  open ctas;
  fetch ctas into cc;
  if ctas%notfound then 
     close ctas;
     result := 'N'; -- no registra
  else
     if nvl(cc.pro_atraso,0) = 0 then
        result := 'E'; -- excelente
     elsif nvl(cc.pro_atraso,0) < 60 then
        result := 'B'; -- bueno
     elsif nvl(cc.pro_atraso,0) < 180 then
        result := 'R'; -- regual
     else 
        result := 'M'; -- malo
     end if;       
  end if;
  return(Result);
exception
  when others then 
     raise_application_error(-20000,'fug_com_pago '||sqlerrm);  
end fug_com_pago;
/

