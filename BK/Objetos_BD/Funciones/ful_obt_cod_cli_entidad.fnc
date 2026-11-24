create or replace function it.ful_obt_cod_cli_entidad (/*p_fecha in ge_movimientos.fecha%type,
p_hora in ge_movimientos.hora%type, 
p_cod_usuario in ge_movimientos.cod_usuario%type,*/
p_cod_mad_padre in ge_movimientos.cod_mad_padre%type,
p_tip_ope_cambio in ge_movimientos.cod_tip_ope_cambio%type,
p_cod_persona in varchar2)
return varchar2 is

v_cod_entidad varchar2(10);
v_cod_cliente varchar2(10);
v_cod_sec_contable ge_clientes.cod_sec_contable%type;
/* retorna el código de clasificación del cliente y código de la entidad concatenados */
/* formato de salida: cod_cliente~cod_entidad */
begin
  if p_cod_mad_padre in (73) then -- arbitrajes
     v_cod_cliente := 4;        
  elsif p_cod_mad_padre in (74) then -- canjes 
     v_cod_cliente := 5;
  else -- compra / venta
     if p_tip_ope_cambio in (14,29) then -- transferencias
       v_cod_cliente := 9;
     --si es cliente es el banco es un movimiento interno
     else
        begin
          select 6
            into v_cod_cliente
            from ge_par_generales
           where cod_persona = p_cod_persona;
        exception
           when others then
              v_cod_cliente := null;
        end;      
     end if;   
     if v_cod_cliente is null then
        --determinar tipo de cliente
         begin
           select ge_clientes.cod_sec_contable
           into v_cod_sec_contable
           from ge_clientes
           where cod_persona = P_COD_PERSONA;
           
           if v_cod_sec_contable = 'N' then -- sector particular
               v_cod_cliente := 3;
           elsif v_cod_sec_contable in ('F','I') then  -- sector financiero
              --es banco
              begin
                 select to_char(cod_bco_central)
                   into v_cod_entidad
                   from ge_bancos
                  where cod_persona = p_cod_persona
                    and rownum =1;
                    
                 v_cod_cliente := 1;
                
              exception
                when no_data_found then
                  v_cod_cliente := null;
              end;
              --es casa de cambios
              if v_cod_cliente is null then
                 begin
                    select substr(val_parametro,1,10)
                      into v_cod_entidad
                      from ge_par_entes a, ge_entes b
                     where a.cod_ente = b.cod_ente
                       and b.cod_persona = p_cod_persona
                       and b.tipo = 'CC' 
                       and parametro in ('COD_ENT_CAMBIOS')
                       and rownum =1;
                    
                    v_cod_cliente := 2;
                    
                 exception
                   when no_data_found then
                     v_cod_cliente := null;
                 end;
              end if;
              --es financiera
              if v_cod_cliente is null then
                 begin
                    select substr(val_parametro,1,10)
                      into v_cod_entidad
                      from ge_par_entes a, ge_entes b
                     where a.cod_ente = b.cod_ente
                       and b.cod_persona = p_cod_persona
                       and b.tipo = 'FI'
                       and parametro in ('COD_ENT_FINANCIERA')
                       and rownum =1;
                    
                    v_cod_cliente := 8;
                    
                 exception
                   when no_data_found then
                     v_cod_cliente := null;
                 end;
              end if;
                            
           end if;
         exception
           when no_data_found then
             --no existe la persona
             --v_cla := 5; -- Cuando es una persona va como sector particular
             v_cod_cliente := 3;
         end;    
     end if;
  end if;


  return trim(v_cod_cliente)||'~'||trim(v_cod_entidad);
  
exception
   when no_data_found then
      return 0;
   when others then
      raise_Application_error(-20000,'Obt.Entidad '||sqlerrm);
end;
/

