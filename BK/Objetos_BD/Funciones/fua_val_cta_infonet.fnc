create or replace function it.FUA_VAL_CTA_INFONET
 (p_nro_cuenta in varchar2,
  p_nro_bin in varchar2)
  return varchar2 is

/* función que recibe el nro de cuenta de infonet y verifica que exista en la base
Busca en el formato recibido y si no encuentra busca con el cero inicial 
esto aplica sólo a ctas vistas 

Proyecto:SDBIN8TDD-1 Parametro p_nro_bin agregado para obtener correctamente la TDD
*/  

v_nro_cuenta  ge_cuentas.nro_cuenta%type;
v_cuenta      ge_cuentas.nro_cuenta%type;
v_cuenta_num  number := to_number(p_nro_cuenta);
v_exi_cta     number;
BEGIN
 --- Verificar si la cuenta de debito existe en Ge_cuentas, si no existe se presume es una cuenta
 --- que esta viniendo en el formato del banco, convertir al formato IT
 Select count(*) into v_exi_cta
  from ge_cuentas
 where nro_cuenta = p_nro_cuenta
   and cod_modulo in (3,4);
 if v_Exi_cta = 0 then   -- no existe, entonces convertir
   v_cuenta := lpad(substr(v_cuenta_num,1,length(v_cuenta_num)-7 ),2,'0')|| --Sucursal
               case when substr(v_cuenta_num,length(v_cuenta_num) - 6,1) in ('1', '3') then '01'
               when substr(v_cuenta_num,length(v_cuenta_num) - 6,1) in ('2', '4') then '02' end|| --Tipo
               substr(v_cuenta_num,-6); 
  else
   v_cuenta := p_nro_cuenta;
  end if;
-- 
 Begin     
  Select nro_cuenta
    into v_nro_cuenta
    from ge_cuentas
   where nro_cuenta = v_cuenta   --to_number(p_nro_cuenta); --para sacar los 0 demás que tenga adelante
     and cod_modulo in (3,4);
   --  
   return v_nro_cuenta;
   --
exception
   when no_data_found then
      if fug_obt_tip_implementacion = 9 then
         begin 
          --la cuenta tiene 0 inicial si la oficina está entre el 1 y 9
          Select nro_cuenta
            into v_nro_cuenta
            from ge_cuentas
           where nro_cuenta = concat('0', to_number(p_nro_cuenta));
           return v_nro_cuenta;
        exception
           when no_data_found then
             raise_application_error(-20001,'No existe la Cuenta: '||concat('0', p_nro_cuenta));
        end;
      else
        begin
          select nro_cta_cliente
            into v_nro_cuenta
          from ah_tar_cta_ficticias
          where to_number(nro_cuenta) = to_number(p_nro_cuenta)
            and nro_bin               = p_nro_bin;
          return v_nro_cuenta;
        exception
          when no_data_found then  
           raise_application_error(-20002,'No existe la Cuenta: '||p_nro_cuenta);
        end;     
      end if;
   when others then
      raise_application_error(-20000,'Recup.Cta '||sqlerrm);
 end;
END;
/

