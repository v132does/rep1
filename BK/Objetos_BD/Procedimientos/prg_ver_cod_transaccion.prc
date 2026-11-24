create or replace procedure it.PRG_VER_COD_TRANSACCION(P_COD_TRANSACCION IN NUMBER) is
begin
 declare
    cursor c_transacciones is 
      select cod_transaccion from ge_transacciones where
        cod_modulo in (4,3); 

  v_esta  char(1);
  
  begin    
   if p_cod_transaccion is not null then
     for reg in c_transacciones loop
      If p_cod_transaccion = reg.cod_transaccion then 
         v_esta := 'S';
      end if;
     end loop;
    
      If nvl(v_esta,'N') = 'N' then      
       raise_application_error(-20000,'Valor incorrecto de Transacción ');
      end if;
   end if; 
  end;
end PRG_VER_COD_TRANSACCION;
/

