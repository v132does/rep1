create or replace procedure it.PRG_VER_NRO_CTA(P_NRO_CUENTA IN VARCHAR2) is
begin
declare
  v_error  char(1);
  v_estado        ah_cta_vistas.estado%type;
  v_cod_modulo    ah_cta_vistas.cod_modulo%type;
  v_cod_modalidad ah_cta_vistas.cod_modalidad%type;
      
  begin    

     select cod_modulo, cod_modalidad into v_cod_modulo, v_cod_modalidad from
      ge_cta_clientes where nro_cuenta = p_nro_cuenta 
       and relacion = 'P';

    If v_cod_modulo not in (3,4) then 
       v_error := 'S';
    else
       ---- busca en Ahorro a la Vista
       if v_cod_modalidad = 31 then 
         begin
           select estado into v_estado from ah_cta_vistas where
              nro_cuenta = p_nro_cuenta ;
       ---- verifica estado de la cuenta 
            if v_estado in ('A','C','T','D') then
              raise_application_error(-20001,'Valor incorrecto del estado de la cta ');                        
            end if;  

         exception
           when no_data_found then
              raise_application_error(-20002,'Valor incorrecto. No encuentra Cuenta ');                                 
         end;
        ---- busca en Cuenta Corriente
       elsif v_cod_modalidad = 41 then    
         begin
           select estado into v_estado from cc_cta_corrientes where
              nro_cuenta = p_nro_cuenta;
       ---- verifica estado de la cuenta 
            if v_estado in ('A','C','T','D') then
              raise_application_error(-20001,'Valor incorrecto del estado de la cta ');                        
            end if;  

         exception
           when no_data_found then
              raise_application_error(-20004,'Valor incorrecto. No encuentra Cuenta ');                                 
         end;
       else
         v_error := 'S';
       end if;
    end if;
    
    If nvl(v_error,'N') = 'S' then      
    raise_application_error(-20000,'Valor incorrecto de Nro.Cuenta, no es Ahorro Vista ni Cta.Cte ');
    end if;
 exception
    when no_data_found then
      raise_application_error(-20006,'Valor incorrecto de Nro.Cuenta ');   
 end;
end PRG_VER_NRO_CTA;
/

