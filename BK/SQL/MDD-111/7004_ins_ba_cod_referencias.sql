-- Enlace MES_PRO_MODALIDAD -> MMCTARRE (plantilla mod 127 + descripcion de cada modalidad nueva)
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

insert into it.ba_cod_referencias (dominio, significado, val_minimo, val_maximo, abreviatura, activo)
select ref.dominio, mod.descripcion, to_char(mod.cod_modalidad), ref.val_maximo, ref.abreviatura, ref.activo
  from it.ge_modalidades mod
 cross join (
        select dominio, val_maximo, abreviatura, activo
          from it.ba_cod_referencias
         where dominio = 'MES_PRO_MODALIDAD'
           and val_minimo = '127'
       ) ref
 where mod.cod_modulo = 10
   and mod.cod_modalidad in (138, 139, 140)
   and not exists (
         select 1 from it.ba_cod_referencias x
          where x.dominio = ref.dominio
            and x.val_minimo = to_char(mod.cod_modalidad));

commit;
/
