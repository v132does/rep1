CREATE OR REPLACE FUNCTION IT.FUE_VAL_FILTROS(P_COD_CONSULTA   BA_CONSULTAS.COD_CONSULTA%TYPE,
                                           P_FILTROS        BA_CONSULTAS.FILTROS%TYPE) RETURN VARCHAR2 IS

--DE-2244 - CD - Optimizar la consulta dinamica HISCRC_NEW - HISTORICO DE DEUDAS DEL CLIENTE CRC NEW - DYD-SDSL-3338
--LCabrera - Agosto/16
v_dat_analizar   ba_consultas.filtros%type := upper(p_filtros);
v_resultado      varchar2(400);
v_val_buscado    number(3);
v_des_parametros varchar2(400);
v_can_parametro  number(3) := 0;

cursor c_filtros is
select g.nom_referencia parametro,
       g.descripcion des_parametro,
       p.per_fil_rango,
       length(g.nom_referencia) + 4 largo,
       instr(v_dat_analizar,'(') par_inicial,
       instr(v_dat_analizar,')') par_final       
  from ba_par_consultas p, ge_filtros g
 where p.cod_campo = g.cod_campo
   and p.cod_consulta = p_cod_consulta
   and nvl(p.per_fil_rango, 'S') = 'N';


begin

 if v_dat_analizar is not null then
    for c_fil in c_filtros loop
      if instr(v_dat_analizar, c_fil.parametro) > 0 then

         v_val_buscado := instr(substr(v_dat_analizar, instr(v_dat_analizar, c_fil.parametro), c_fil.largo),'='); 

         if  v_val_buscado = 0 then

            v_can_parametro := v_can_parametro +1;
            if v_can_parametro > 1 then
               v_des_parametros := v_des_parametros||','||c_fil.des_parametro;
               v_resultado := 'Parámetros '||v_des_parametros||' No permiten consultar por rango.';
            else
               v_des_parametros := c_fil.des_parametro;
               v_resultado := 'Parámetro '||c_fil.des_parametro||' No permite consultar por rango.';
            end if;  

         end if;

      end if;   
    end loop; 
 end if;

 return v_resultado;

exception
  when others then
    v_resultado := null;
    return v_resultado;
end;
/

