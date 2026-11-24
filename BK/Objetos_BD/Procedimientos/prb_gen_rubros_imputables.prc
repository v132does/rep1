CREATE OR REPLACE PROCEDURE IT.PRB_GEN_RUBROS_IMPUTABLES  is
  v_contador    number(7):= 2;
  v_valor_nuevo varchar2(150); 
  v_padre varchar2(150);
  v_naturaleza varchar2(1);
  v_cod_moneda varchar2(10);
  v_existe varchar2(1);
  v_tiene_l varchar2(5);
  v_regis_rubro varchar2(1);
  FUNCTION LF_OBT_RUB_PADRE(p_cod_rubro in varchar2)
  RETURN varchar2 IS
  BEGIN
     if substr(p_cod_rubro,3,1) <> '0' then
        --return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,12);
        return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,10)||'00';
     elsif substr(p_cod_rubro,3,1) = '0' then
        return substr(p_cod_rubro,1,2)||'0'||substr(p_cod_rubro,4,7)||'00000';
     else
        return p_cod_rubro;
     end if;
  end ;
  
  FUNCTION LF_REG_RUBRO(p_cod_valor in varchar2)
  RETURN varchar2 IS
  BEGIN
    v_regis_rubro := 'S';
     --Con esto controlo los resultados que no deben generarse como rubro contable
     if substr( p_cod_valor,1,2) = '13'   then
          if substr( p_cod_valor,4,2) = '10' then
             if substr( p_cod_valor,6,3) = '131' then
                 if substr( p_cod_valor,9,2) in ('01','10','13','15') then
                   v_regis_rubro := 'N' ;
                 end if;
             Elsif substr( p_cod_valor,6,3) = '141' and substr( p_cod_valor,9,2) in ('01')  then
                   v_regis_rubro := 'N' ;
             Elsif substr( p_cod_valor,6,3) in ('391') then
                 if substr( p_cod_valor,9,2) in ('01','03','07','08','09','10','11','13','14','15','16','18','20') then
                   v_regis_rubro := 'N' ;
                 end if;
             Elsif substr( p_cod_valor,6,3) in ('417') then
                 if substr( p_cod_valor,9,2) in ('01','03','10','11','13','15') then
                    v_regis_rubro := 'N' ;
                 end if;
             end If;
          -------Fin 10
          Elsif substr( p_cod_valor,4,2) = '20' then
             if substr( p_cod_valor,6,3) in ('145','155', '157') then
                 if substr( p_cod_valor,9,2) in ('01','10','11','13','15') then
                    v_regis_rubro := 'N' ;
                 end if;
             elsif  substr( p_cod_valor,6,3) in ( '435') then
                 if substr( p_cod_valor,9,2) in ('01','10','11','13','14','15') then
                    v_regis_rubro := 'N' ;
                 end if;
             end if;
          End if;
     Elsif substr( p_cod_valor,1,2) = '16'   then
           if substr( p_cod_valor,4,2)  = '50' then
              if substr( p_cod_valor,6,3)  = '385' then
                 if substr( p_cod_valor,9,2) in ('01','10','11','13','15') then
                   v_regis_rubro := 'N' ;
                 end if;
              end if;
            end if;
     Elsif substr( p_cod_valor,1,2) = '21'   then
          if substr( p_cod_valor,4,2)   = '10' then
              if substr( p_cod_valor,6,3)  = '102' then
                 if substr( p_cod_valor,9,2) in ('01','13','15') then
                   v_regis_rubro := 'N' ;
                 end if;
              elsif substr( p_cod_valor,6,3) in  ('104','196','284','306')  then
                  if substr( p_cod_valor,9,2) in  ('01','10','11','13','15') then
                    v_regis_rubro := 'N' ;
                  end if;
               end if;
          elsif substr( p_cod_valor,4,2) = '30' then
              if substr( p_cod_valor,6,3)  in ('118','128','130','392') then
                 if substr( p_cod_valor,9,2) in  ('01','10','11','13','15') then
                   v_regis_rubro := 'N' ;
                 end if;
              end if;
          end if;
     end if;
  
     RETURN nvl(v_regis_rubro,'S');
     
  end ;
  

  
  
BEGIN
  ----LA principal-------------
  declare  cursor tipos_asientos is
  select distinct a.cod_rubro cod_rubro,a.cod_sec_contable, substr(a.cod_rubro,9,2) tipo_deu,
  substr(a.cod_rubro,11,3) sector, a.ind_residente
  from ge_tip_asientos a
  where length(a.cod_rubro) = 15   ;

  
  begin
  for tipos in tipos_asientos loop
    begin
      Select aa.cod_moneda
      into v_cod_moneda
      from ge_tip_asientos aa
      where aa.cod_rubro = tipos.cod_rubro
      and rownum = 1;
    exception
      when others then
         raise_application_error('-20000','Al buscar moneda:'||tipos.cod_rubro||' '||sqlerrm);
    end;
 
    ----  Naturaleza  ---------------
    If substr(tipos.cod_rubro,1,1) IN ('7','1') or substr(tipos.cod_rubro,1,2) IN ('41','51')    then
        v_naturaleza := '+';
        if substr(tipos.cod_rubro,1,1) = ('1') and substr(tipos.cod_rubro,9,1) = ('9') then
            v_naturaleza := '-';
        elsif substr(tipos.cod_rubro,1,1) = ('1') and substr(tipos.cod_rubro,4,2) in ('90','70') then
            v_naturaleza := '-';
        end if; 
    elsif substr(tipos.cod_rubro,1,1) IN ('2','6','3') or  substr(tipos.cod_rubro,1,2) IN ('42','52')  then
        v_naturaleza := '-';
        if substr(tipos.cod_rubro,1,1) = ('2') and substr(tipos.cod_rubro,9,2) in ('82','92','93') then
           v_naturaleza := '+';
        end if;
    else
      v_naturaleza := '+';
    end if;
    -----   Fin Naturaleza ----------
    
    If  substr(tipos.cod_rubro,3,1) = 'P' then
     v_contador := 2; 
     Loop
        v_valor_nuevo := substr(tipos.cod_rubro, 1, 2) || v_contador || substr(tipos.cod_rubro, 4);   
        v_padre       := lf_obt_rub_padre(v_valor_nuevo);
        if tipos.tipo_deu = 'TD' then
           
           if tipos.cod_sec_contable in ('F','P','N') or tipos.cod_sec_contable  is null then         
              declare  cursor tip_deu is 
              Select distinct x.tipdeudor from (
              select lpad(t.Cod_Tip_Deudor, 2, '0')  tipdeudor  
              from ge_tip_deudores t 
              where t.cod_sec_contable = tipos.cod_sec_contable
              and tipos.cod_sec_contable is not null 
              and ( ( tipos.cod_sec_contable = 'F' and ( (tipos.ind_residente = 'S' and t.ind_residente = 'S') or (tipos.ind_residente = 'N' and t.ind_residente = 'N') OR NVL(tipos.ind_residente,'X')='X' ) )
                 OR tipos.cod_sec_contable <> 'F' ) 
              union all
              select lpad(t.Cod_Tip_Deudor, 2, '0')  tipdeudor  
              from ge_tip_deudores t 
              where tipos.cod_sec_contable is  null
               ) x;              
              
              begin
                for td in tip_deu loop
                   
                   ---Consulto sector
                   if tipos.sector = 'SEC' then
                     v_valor_nuevo := substr(tipos.cod_rubro, 1, 2) || v_contador || substr(tipos.cod_rubro, 4, 5) || td.tipdeudor || '000' || substr(tipos.cod_rubro, 14, 2 );
                   else
                    v_valor_nuevo := substr(tipos.cod_rubro, 1, 2) || v_contador || substr(tipos.cod_rubro, 4, 5) || td.tipdeudor || substr(tipos.cod_rubro, 11, 5 );
                   end if;
                   v_padre       := lf_obt_rub_padre(v_valor_nuevo);
                   --Vuelvo a consultar, pasa que despues de ser convertido, es igual a otro que si ya esta en la tabla
                   Begin
                      select distinct 'S' into v_existe from ge_tip_asientos a 
                      where a.cod_rubro = v_valor_nuevo ;
                   exception
                     when others then
                       v_existe := 'N';
                   End;  
                    
                   If nvl(v_existe,'X') <> 'S' then  --tiene P y TD 
                        If LF_REG_RUBRO(v_valor_nuevo) = 'S' then
                          begin
                          INSERT INTO CB_RUBROS
                          (COD_RUBRO,  COD_MONEDA,COD_RUB_PADRE, DESCRIPCION,ABREVIATURA,IMPUTABLE, NIVEL,
                          TIPO,NATURALEZA)
                          VALUES
                          (v_valor_nuevo,v_cod_moneda, v_padre,'SIN DESCRIPCION','SIN','S',7,substr(tipos.cod_rubro,1,1) , v_naturaleza);
                          exception
                           when others then
                             null;
                          end;
                        END IF;
                   End if;
                end loop;
              end;
           
            End if;
        else ---No es TD, pero es P
           ---Consulto sector
           if tipos.sector = 'SEC' then
              v_valor_nuevo := substr(tipos.cod_rubro, 1, 2) || v_contador || substr(tipos.cod_rubro, 4, 7) || '000' || substr(tipos.cod_rubro, 14, 2 );
              v_padre       := lf_obt_rub_padre(v_valor_nuevo);
           end if;
           --Vuelvo a consultar, pasa que despues de ser convertido, es igual a otro que si ya esta en la tabla
           Begin
              select distinct 'S' into v_existe from ge_tip_asientos a 
              where a.cod_rubro = v_valor_nuevo ;
           exception
             when others then
               v_existe := 'N';
           End;  
           If nvl(v_existe,'X') <> 'S' then ---ES P pero no TD 
             If LF_REG_RUBRO(v_valor_nuevo) = 'S' then
                begin
                 INSERT INTO CB_RUBROS
                 (COD_RUBRO,  COD_MONEDA,COD_RUB_PADRE, DESCRIPCION,ABREVIATURA,IMPUTABLE, NIVEL,
                 TIPO,NATURALEZA)
                 VALUES
                 (v_valor_nuevo,v_cod_moneda, v_padre,'SIN DESCRIPCION','SIN','S',7,
                  substr(tipos.cod_rubro,1,1) , v_naturaleza);
                 exception
                 when others then
                   null;
                   --raise_application_error('-20000','Insert into cb_rubros1:'||tipos.cod_rubro||' Valor nuevo: '||v_valor_nuevo||'  - '||sqlerrm);
                 end;
              End if;
            end if;
         end if;
         v_contador    := v_contador + 1;      
      EXIT WHEN v_contador = 9;

      END LOOP;

    ELSE --No tiene una P como tercer dígito.
       --Pero puede que tenga la TD
       
        
       if tipos.tipo_deu = 'TD' then
         
           if tipos.cod_sec_contable in ('F','P','N') or tipos.cod_sec_contable  is null then
              
             declare  cursor tip_deu is              
             Select distinct x.tipdeudor from (
              select lpad(t.Cod_Tip_Deudor, 2, '0')  tipdeudor  
              from ge_tip_deudores t 
              where t.cod_sec_contable = tipos.cod_sec_contable
              and tipos.cod_sec_contable is not null             
              and ( ( tipos.cod_sec_contable = 'F' and ( (tipos.ind_residente = 'S' and t.ind_residente = 'S') or (tipos.ind_residente = 'N' and t.ind_residente = 'N') OR NVL(tipos.ind_residente,'X')='X' ) )
                 OR tipos.cod_sec_contable <> 'F' )                
               ) x;   
             
              begin
                for td in tip_deu loop
                   ---Consulto sector
                   if tipos.sector = 'SEC' then
                     v_valor_nuevo := substr(tipos.cod_rubro, 1,  8) || td.tipdeudor || '000' || substr(tipos.cod_rubro, 14, 2 );
                   else
                     v_valor_nuevo := substr(tipos.cod_rubro, 1,  8) || td.tipdeudor  || substr(tipos.cod_rubro, 11, 5 );
                   end if;               
                   v_padre       := lf_obt_rub_padre(v_valor_nuevo);
                   --Vuelvo a consultar, pasa que despues de ser convertido, es igual a otro que si ya esta en la tabla
                   Begin
                      select distinct 'S' into v_existe from ge_tip_asientos a 
                      where a.cod_rubro = v_valor_nuevo ;
                   exception
                     when others then
                       v_existe := 'N';
                   End;  
                   If nvl(v_existe,'X') <> 'S' then ---No es P pero si TD
                      If LF_REG_RUBRO(v_valor_nuevo) = 'S' then
                         begin
                          INSERT INTO CB_RUBROS
                          (COD_RUBRO,  COD_MONEDA,COD_RUB_PADRE, DESCRIPCION,ABREVIATURA,IMPUTABLE, NIVEL,
                          TIPO,NATURALEZA)
                          VALUES
                          (v_valor_nuevo,v_cod_moneda, v_padre,'SIN DESCRIPCION','SIN','S',6,substr(tipos.cod_rubro,1,1) , v_naturaleza);
                         exception
                           when others then
                             null;
                           -- raise_application_error('-20000','Insert into cb_rubros tipdeu'||sqlerrm);
                         end;
                      End if;
                   END IF;
                   
                end loop;
              end;
          
            End if;
        else ---No tiene la P ni la TD, se inserta tal cual
          
            ---Consulto sector
            if tipos.sector = 'SEC' then
              v_valor_nuevo := substr(tipos.cod_rubro, 1,  10) || '000' || substr(tipos.cod_rubro, 14, 2 );
            else
              v_valor_nuevo := tipos.cod_rubro;
            end if;               
             v_padre       := lf_obt_rub_padre(v_valor_nuevo);
             If LF_REG_RUBRO(v_valor_nuevo) = 'S' then
               begin
               INSERT INTO CB_RUBROS
               (COD_RUBRO,  COD_MONEDA,COD_RUB_PADRE, DESCRIPCION,ABREVIATURA,IMPUTABLE, NIVEL,
               TIPO,NATURALEZA)
               VALUES
               (v_valor_nuevo,v_cod_moneda, v_padre,'SIN DESCRIPCION','SIN','S',6,
               substr(tipos.cod_rubro,1,1), v_naturaleza);
               exception
                 when others then
                   null;
                  -- raise_application_error('-20000','Insert into cb_rubros valor rubro 3 :'||tipos.cod_rubro||' '||sqlerrm);
               end; 
             End if;
         end if;
     End if;---De si tiene P en su tercer Dígito
    
     --Con esto controlo que no siga habiendo alguna letra y evitar generar rubros asi
     begin
      select REGEXP_REPLACE(v_valor_nuevo,' *[0-9]*') 
      into v_tiene_l from dual;
     exception       
       when no_data_found then
         v_tiene_l := 'N';
       when others then
         v_tiene_l := 'N';
         null;
     end;
     IF nvl(v_tiene_l,'N') <> 'N' then
          raise_application_error('-20000','Tiene algo de letra:'||v_tiene_l||'  y el valor cambiado es:'||v_valor_nuevo||' VALOR de tip_asiento:'||tipos.cod_rubro||' SECTOR:'||tipos.cod_sec_contable||sqlerrm);
     end if; 
     
   end loop;
 end;

END;
/

