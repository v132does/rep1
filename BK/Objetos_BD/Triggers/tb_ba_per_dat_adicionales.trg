CREATE OR REPLACE TRIGGER IT.tb_ba_per_dat_adicionales
   BEFORE INSERT OR UPDATE ON "IT"."BA_PER_DAT_ADICIONALES"
   FOR EACH ROW
DECLARE
   v_pre_rol_mov_linea ge_par_dinamicos.val_parametro%TYPE;
   v_segmento ge_clientes.cod_seg_cliente%type;
BEGIN
   IF UPDATING AND nvl(pae_cnf.g_programa,'x') = 'EMADIPER' THEN
      IF INSTR(:new.parametro, fug_obt_pardinamico('PRE_ADI_MTO_LINEA', 1)) <> 0
         and :new.val_parametro <> :old.val_parametro THEN
         v_pre_rol_mov_linea := fug_obt_pardinamico('PRE_ROL_MOD_LINEA', 1);
         IF fug_tie_rol_asociado(USER, v_pre_rol_mov_linea) = 'N' THEN
            raise_application_error(-20000, 'El usuario '||USER||' no tiene asignado '||
                                            'el Rol '||v_pre_rol_mov_linea||' autorizado '||
                                            'para modificar la Línea de Crédito de Libradores.');
         END IF;
      END IF;
   END IF;
   /*SOLO PARA LOS SEGMENTOS DE PEQUEÑAS EMPRESAS 3, MEDIANA EMPRESA 4, GRANDES EMPRESAS 5*/
   if inserting or updating AND nvl(pae_cnf.g_programa,'x') = 'EMADIPER' then 
     begin
         select cod_seg_cliente 
           into v_segmento
           from ge_clientes
          where cod_persona = :new.cod_persona ;
      exception
        when no_data_found then
          null;
    end;
     if v_segmento in (3,4,5) then --val no puede ser cero
     if :new.parametro = 'CANT_TOTAL_EMPLEADOS' then
      if :new.val_parametro <  FUG_OBT_PAR_DEFADICIONAL('CANT_TOTAL_EMPLEADOS') then
        raise_application_error(-20001,'Dato no puede ser cero.');
      end if;
      end if;
      if :new.parametro = 'CANT_EMPLEADOS_FIJOS' then
      if :new.val_parametro <  FUG_OBT_PAR_DEFADICIONAL('CANT_EMPLEADOS_FIJOS') then
        raise_application_error(-20002,'Dato no puede ser cero.');
      end if;
     end if;
   end if;
   end if;
END;
/

