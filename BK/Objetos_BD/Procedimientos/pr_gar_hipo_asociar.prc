create or replace procedure it.pr_gar_hipo_asociar as

  cursor c_garantias is
  select a.nro_cuenta, a.nro_garantia 
  from pr_gar_asociar_tmp a, pr_cta_prestamos p, ge_modalidades m
  where a.nro_cuenta = p.nro_cuenta
    and p.cod_modulo = 6
    and p.cod_modulo = m.cod_modulo
    and p.cod_modalidad = m.cod_modalidad
    and m.descripcion like '%HIPO%';

  v_cant_gar number;
  v_monto ge_movimientos.monto%type;
  v_cod_persona ba_personas.cod_persona%type;  

begin 
     --Verificar si existen garantias a asociar
     select count(*) into v_cant_gar
     from pr_gar_asociar_tmp a;

     if v_cant_gar = 0 then
        raise_application_error(-20000, 'No existen datos a Asociar en la tabla pr_gar_asociar_tmp'); 
     end if;   

     --Verificar que no existan Garantías Vencidas
     select count(a.nro_garantia) into v_cant_gar
     from pr_garantias g, pr_gar_asociar_tmp a      
     where g.nro_garantia = a.nro_garantia
       and g.estado = 'V';
       
     if v_cant_gar > 0 then
        raise_application_error(-20000, 'Existen Garantías Vencidas. Favor cambiar de estado primero'); 
     end if;    
     
     --Recorrer las Garantias a Asociar
     for tmp in c_garantias loop
     
         --Buscar Valor Edilicio
          select sum(p.sal_capital) into v_monto
          from pr_cuotas p
          where p.nro_cuenta = tmp.nro_cuenta;            
          
          if SQL%NOTFOUND then
             raise_application_error(-20000, 'No existe monto para la garantia nro: '||tmp.nro_garantia);
          end if;
          
          --Buscar Código de Persona
          select cli.cod_persona into v_cod_persona
          from pr_cta_prestamos p, ge_cta_clientes gcc, ge_clientes cli
          where p.nro_cuenta = gcc.nro_cuenta
            and gcc.relacion = 'P'
            and gcc.cod_persona = cli.cod_persona
            and p.nro_cuenta = tmp.nro_cuenta;
          
          if SQL%NOTFOUND then 
             raise_application_error(-20000, 'No existe Cliente asociado a la cuenta: '||tmp.nro_cuenta);
          end if;

          begin           
              --insertar en pr_cta_garantias
              insert into pr_cta_garantias 
              (nro_cuenta, nro_garantia, cod_garantia, mto_aplicado, mto_con_computable, mto_apl_computable, 
              mto_con_nocomputable, porcentaje, cod_persona, mto_riesgo) values 
              (tmp.nro_cuenta, tmp.nro_garantia, 3, v_monto, 0, 0, null, null, v_cod_persona, 0);
          exception when others then
              raise_application_error(-20000, 'No se pudo insertar Nro. Cta.: '||tmp.nro_cuenta||'. Nro. Gar.:'||tmp.nro_garantia||'!');
          end;
     end loop;
end;
/

