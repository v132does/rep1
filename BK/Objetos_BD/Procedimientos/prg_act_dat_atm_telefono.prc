CREATE OR REPLACE PROCEDURE IT.PRG_ACT_DAT_ATM_TELEFONO IS
   v_existe   varchar2(1);
   v_area     varchar2(10);
   v_telefono varchar2(10);
   cursor c_cursor is
     select a.cod_persona,a.tipo,a.valor,a.actualizado,a.rowid id
       from ba_dat_atm a
      where a.actualizado = 'N'
        and a.tipo in ('A','H');
   procedure lp_act_migracion(p_cod_persona varchar2, p_area varchar2, p_telefono varchar2) is
     v_fecha date := sysdate;
   begin
     update ba_act_dat_clientes a
        set a.migrado = 'S',
            a.fec_migracion = v_fecha
      where a.cod_persona = p_cod_persona
        and a.tel_numero = p_telefono
        and a.tel_area = p_area
        and a.estado = 'C';
   end;
BEGIN
  BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END; 
  for c in c_cursor loop
   -- verificar si el nro telefono ya existe en ba_telefonos
   v_area     := substr(c.valor,1,4);
   v_telefono := substr(c.valor,5,6);
   begin
     select 'S'
       into v_existe
       from ba_telefonos a
      where a.cod_persona = c.cod_persona
        and a.area = v_area
        and a.telefono = v_telefono
        and rownum = 1;
   exception
     when no_data_found then
       v_existe := 'N';
     when others then
       raise_application_error(-20000,'persona: '||c.cod_persona||sqlerrm);
   end;
   if v_existe = 'N' then
     begin
     -- insertar en ba_telefonos tipo A (celular ATM)
     insert into ba_telefonos
        (cod_persona, tipo,tip_linea, telefono, area)
      values
        (c.cod_persona,c.tipo,'C',v_telefono,v_area);
      exception
        when others then
          raise_application_error(-20001,'persona: '||c.cod_persona||sqlerrm);
      end;
      lp_act_migracion(c.cod_persona,v_area,v_telefono);
   else
     update ba_telefonos a
        set a.observacion = a.observacion||'/ Telefono actualizado vía ATM.'
      where a.cod_persona = c.cod_persona
        and a.area = v_area
        and a.telefono = v_telefono;
        if sql%notfound then
          raise_application_error(-20002,'Error al actualizar. Persona: '||c.cod_persona||sqlerrm);
        end if;
        lp_act_migracion(c.cod_persona,v_area,v_telefono);
   end if;
   update ba_dat_atm b
      set b.actualizado = 'S'
    where b.rowid = c.id;
  end loop;
   ---Control para evitar que se ingrese comentarios o nombres de ciudades como codigo de area
END;
/

