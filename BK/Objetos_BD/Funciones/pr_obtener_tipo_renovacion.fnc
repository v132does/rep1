CREATE OR REPLACE FUNCTION IT."PR_OBTENER_TIPO_RENOVACION" (p_congru varchar2,p_propren number)
return char
is
      v_prim_dig varchar2(3);

begin
      v_prim_dig := substr(trim(p_congru),1,3);

       --Préstamos a plazo fijo
      if(v_prim_dig = '169')then

          if(substr(trim(p_congru),5,2) = '04') then
             return 'N';--Renovado
          elsif(substr(trim(p_congru),5,2) = '06')then
             return 'R';--Refinanciado
          elsif (substr(trim(p_congru),5,2) = '08')then
             return 'E';--Reestructurado
          end if;

          return null;

      end if;

      --Préstamos amortizables
      if(v_prim_dig = '173') then

          if(substr(trim(p_congru),5,2) = '06') then
             return 'N';--Renovado
          elsif(substr(trim(p_congru),5,2) = '08')then
             return 'R';--Refinanciado
          elsif (substr(trim(p_congru),5,2) = '10')then
             return 'E';--Reestructurado
          end if;

          return null;

      end if;

      --417: Préstamos Renovados, Reestructurados, Refinanciados Sector Financiero
      --209: Préstamos financiados por la AFD
      --265,269,275: Vencidos, En Gestión y Morosos
      --141: Descuento de documentos sector financiero
      --351: Descuento de documentos sector no financiero
      --405: Descuento de cheques sector no financiero
      --273:Préstamos con arreglos
      if(v_prim_dig = '417' or v_prim_dig = '209' or v_prim_dig = '265'
               or v_prim_dig = '269' or v_prim_dig = '275' or v_prim_dig = '141'
                       or v_prim_dig = '351' or v_prim_dig = '405' or v_prim_dig = '273') then

             if(p_propren = 1) then
                return 'N';
             elsif (p_propren = 2) then
                return 'R';
             elsif (p_propren = 3) then
                return 'E';
             end if;

             return null;
      end if;


      --131: Préstamos del sector financiero, los q comienzan con esta cuenta contable si o si son nuevos
      if(v_prim_dig = '131') then
             return 'N';
      end if;
      return null;
exception
      when others then
          /*  registrar_error_fase2('pr_obtener_tipo_renovacion',null,
                            'Cuenta no Manejada para el tipo de renovación'||p_congru,'PR');*/
               return null;
end;
/

