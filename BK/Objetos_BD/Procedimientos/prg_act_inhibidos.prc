create or replace procedure it.prg_act_inhibidos(p_tipo in char) is

  v_max       float := 0;
  v_inh_row ge_per_inhibidas%rowtype;
  v_fec_inicio date;
  v_cod_causa ge_per_inhibidas.cod_causa%type;
  v_cantidad  float := 0;
  v_error     varchar2(300);
  exc_per_no_existe EXCEPTION;
  exc_per_duplicada EXCEPTION;
    
begin
  -- Author  : Christian Leiva
  -- Created : 07/08/2013
  -- Purpose : Actualiza la lista de Inhibidos (ge_per_inhibidas) , si el valor de < p_tipo > es A,
  --           entonces rehabilita todas las personas de un causal especifico, que no se encuentran en un archivo excel (ge_per_inhibidas_tmp),
  --           y luego agrega en la lista de inhibidos (ge_per_inhibidas), lo que figura en el archivo
  begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 1;
  end;
  -- Verifica si existen causales que no corresponden a Inhibición --  
   Select count(*)
     into v_cantidad
     from ge_per_inhibidas_tmp t
    where not exists (Select 1
             from ge_causales c
            where c.cod_causa = t.cod_causa
              and c.tipo = 'I');              
  if v_cantidad > 0 then
     raise_application_error(-20000,'Existen Causales que no corresponden a Inhibición');
  end if;                   
  if p_tipo = 'A' then
     select max(t.fec_inicio)
       into v_fec_inicio
       from ge_per_inhibidas_tmp t;              
    Begin
     select distinct(t.cod_causa)
       into v_cod_causa
       from ge_per_inhibidas_tmp t;      
     exception
        when too_many_rows then
          raise_application_error(-20000,
          'Existe mas de un causal en la Planilla');
     end;        
    -- Rehabilita todas las que no estan en la planilla, de un causal especifico --
    Update ge_per_inhibidas i
       set i.Fec_Rehabilitacion = v_fec_inicio, i.estado = 'D'
     where  i.estado != 'D'
       and i.cod_causa = v_cod_causa;

  end if;
  -- Solo los causales de Inhibición se procesará --
  for a in (Select i.cod_persona, i.cod_causa, i.fec_inicio, i.rowid
              From ge_per_inhibidas_tmp i,ge_causales c
              where i.cod_causa = c.cod_causa 
                and c.tipo = 'I'
                and not exists (Select 1
                                from ge_per_inhibidas t
                                 where t.cod_persona = i.cod_persona
                                 and t.cod_causa = i.cod_causa
                                 and t.estado = 'I')
             order by 1 ) loop
      BEGIN         
        v_error := null;
        
        select max(dd.nro_orden)
          into v_max
          from ge_per_inhibidas dd
         where dd.cod_persona = a.cod_persona;

        v_max := nvl(v_max, 0) + 1;

        Select max(g.descripcion)
          into v_inh_row.detalle
          from ge_causales g
         where g.cod_causa = a.cod_causa;
        
        
        v_inh_row.cod_persona := a.cod_persona;
        v_inh_row.nro_orden   := v_max;
        v_inh_row.cod_causa   := a.cod_causa;
        v_inh_row.fec_inicio  := a.fec_inicio;
        v_inh_row.referencia  := substr(trim(v_inh_row.detalle), 1, 20);
        v_inh_row.origen      := 'BBVA';
        v_inh_row.estado      := 'I';
        
        -- Validamos registros duplicados por codigo de persona        
        select count(cod_persona)
          into v_cantidad
          from ge_per_inhibidas_tmp tmp
         where tmp.cod_persona = a.cod_persona
           and tmp.fec_inicio = a.fec_inicio
         group by cod_persona;

         if v_cantidad <> 1 then 
            raise exc_per_duplicada;
         end if;
         
         -- validamos persona no existe         
         select count(*) 
           into v_cantidad 
           from ba_personas per
          where per.cod_persona = a.cod_persona;
         
         if v_cantidad = 0 then 
            raise exc_per_no_existe;
         end if;
         
        --inserta en tabla ge_per_inhibidas
        insert into ge_per_inhibidas values v_inh_row;
        v_max := 0;
      EXCEPTION
        WHEN exc_per_no_existe THEN
          v_error := 'Riesgo o persona no existe, no insertada';
        WHEN exc_per_duplicada THEN
          v_error := 'Riesgo o persona con varios registros, no insertada';
        WHEN OTHERS THEN
          v_error := substr(SQLERRM, 1, 200);          
      END;
      
      IF v_error IS NOT NULL THEN
        BEGIN
            UPDATE ge_per_inhibidas_tmp
            SET tie_error = 'S', err_descripcion = v_error 
            WHERE rowid = a.rowid;
          EXCEPTION
            WHEN OTHERS THEN            
              NULL;--DO NOTHING
          END;
      END IF;
  end loop;
end prg_act_inhibidos;
/

