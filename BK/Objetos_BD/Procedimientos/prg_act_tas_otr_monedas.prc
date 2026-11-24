CREATE OR REPLACE PROCEDURE IT.PRG_ACT_TAS_OTR_MONEDAS IS
  --El objetivo es recorrer la tabla de tasas (Fijas y Variables) que tengan definida
  --moneda base y generar valor para las otras monedas segun cotizacion vigente.
  -- Las monedas posibles son Guaranies, Dolares y Euros
  --*
  --* Seleccionar todas las tasa que sean de tipo valor y que tengan definido moneda base
  CURSOR C_TASAS is
    select cod_Tasa, cod_mon_base, aplicar
      from ge_tasas
     where tip_valor = 'V'
       and cod_mon_base is not null;
  --*
  v_mon_base        ba_monedas.cod_moneda%type;
  v_cod_Tasa        ge_tasas.cod_tasa%type;
  v_existe          number;
  v_val_maximo      number;
  v_val_minimo      number;
  v_val_hasta       number;
  v_no_actualizable VARCHAR2(1);
  --*
  CURSOR c_monedas is
    select cod_moneda
      from ba_monedas m
     where cod_moneda in ('GS', 'EUR', 'USD')
       and cod_moneda <> v_mon_base;
  --*
  CURSOR c_tas_fijas is
    select *
      from ge_tas_fechas
     where cod_Tasa = v_cod_tasa
       and cod_moneda = v_mon_base
       and cod_persona is null
       and nro_cuenta is null;
  --*
  CURSOR c_tas_variables is
    select *
      from ge_tas_rangos
     where cod_Tasa = v_cod_tasa
       and cod_moneda = v_mon_base
       and nro_cuenta is null
       and cod_persona is null;
  --------------------------------
BEGIN

  
  Begin
    pre_ini_aplicacion;
    pae_cnf.G_COD_MODULO := 1;
  End;

  FOR reg in c_tasas loop
    v_mon_Base := reg.cod_mon_Base;
    v_cod_Tasa := reg.cod_Tasa;
    --- Seleccionar el cursor de monedas distintas a la moneda base,
    --- para generar o actualizar el valor de acuerdo a la cotizacion
    Declare
      Cursor c_monedas is
        select cod_moneda
          from ba_monedas m
         where cod_moneda in ('GS', 'EUR', 'USD')
           and cod_moneda <> v_mon_base
           and cod_moneda not in
               (select f.cod_moneda
                  from ge_tas_fechas f
                 where f.cod_tasa = reg.cod_tasa
                   and f.no_actualizable = 'S')
           and cod_moneda not in
               (select v.cod_moneda
                  from ge_tas_rangos v
                 where v.cod_tasa = reg.cod_tasa
                   and v.no_actualizable = 'S');
    Begin
      For m in c_monedas loop
        --------- PROCESO TASAS FIJAS  ----------
        --- Seleccionar los registros en la moneda Base
        For f in c_tas_fijas loop
          --- Verificar si ya existe con la moneda,
          --- si existe actualizar el valor si no insertar
          Begin
            Select no_actualizable, 1
              into v_no_actualizable, v_existe
              from ge_tas_fechas
             where nvl(cod_modulo, -1) = nvl(f.cod_modulo, -1)
               AND nvl(cod_modalidad, -1) = nvl(f.cod_modalidad, -1)
               AND nvl(cod_sub_modalidad, -1) =
                   nvl(f.cod_sub_modalidad, -1)
               AND nvl(cod_oficina, -1) = nvl(f.cod_oficina, -1)
               AND cod_moneda = m.cod_moneda
               AND nvl(nro_cuenta, 'x') = nvl(f.nro_cuenta, 'x')
               AND nvl(cod_persona, 'x') = nvl(f.cod_persona, 'x')
               AND cod_tasa = f.cod_tasa
               AND fec_vigencia = f.fec_vigencia;
          Exception
            when no_data_found then
              v_existe          := 0;
              v_no_actualizable := 'N';
            when others then
              raise_application_error(-20000,
                                      'ERROR al buscar GE_TAS_FECHAS :  ' ||
                                      SQLERRM);
          End;

          -- Verificar el tipo de aplicacion para no convertir los valores maximo y minimo
          -- que no corresponden a valor si no a cantidad o portentajes.
          If reg.aplicar not in ('CT', 'CE', 'CC', 'PL') and
             nvl(f.val_maximo, 0) <> 0 then
            v_val_maximo := PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                        m.cod_moneda,
                                                        f.val_maximo);
          else
            v_val_maximo := f.val_maximo;
          End if;
          If reg.aplicar not in ('CT', 'CE', 'CC', 'PL') and
             nvl(f.val_minimo, 0) <> 0 then
            v_val_minimo := PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                        m.cod_moneda,
                                                        f.val_minimo);
          else
            v_val_minimo := f.val_minimo;
          End if;
          ------
          If v_existe = 0 then
            --Insertar
            Insert into ge_tas_fechas
              (Cod_Tasa,
               Fec_vigencia,
               cod_oficina,
               Cod_moneda,
               Cod_modulo,
               Cod_modalidad,
               Nro_cuenta,
               Val_maximo,
               Val_minimo,
               val_base,
               Val_tasa,
               Aplicar,
               Fec_vencimiento,
               Observaciones,
               val_Extension,
               Tip_iva,
               Cod_persona,
               Cod_sub_modalidad)
            Values
              (reg.cod_tasa,
               f.fec_vigencia,
               f.cod_oficina,
               m.cod_moneda,
               f.cod_modulo,
               f.cod_modalidad,
               f.Nro_cuenta,
               v_val_maximo,
               v_val_minimo,
               decode(f.val_base,
                      null,
                      null,
                      0,
                      0,
                      PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                  m.cod_moneda,
                                                  f.val_base)),
               decode(f.val_tasa,
                      null,
                      null,
                      0,
                      0,
                      PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                  m.cod_moneda,
                                                  f.val_tasa)),
               f.Aplicar,
               f.fec_vencimiento,
               f.observaciones,
               f.val_extension,
               f.tip_iva,
               f.cod_persona,
               f.cod_sub_modalidad);
          else
            If nvl(V_no_actualizable, 'N') = 'N' then
              Update ge_tas_fechas
                 set val_base = decode(f.val_base,
                                       null,
                                       null,
                                       0,
                                       0,
                                       PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                                   m.cod_moneda,
                                                                   f.val_base)),
                     val_tasa = decode(f.val_tasa,
                                       null,
                                       null,
                                       0,
                                       0,
                                       PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                                   m.cod_moneda,
                                                                   f.val_tasa))
               where nvl(cod_modulo, -1) = nvl(f.cod_modulo, -1)
                 AND nvl(cod_modalidad, -1) = nvl(f.cod_modalidad, -1)
                 AND nvl(cod_sub_modalidad, -1) =
                     nvl(f.cod_sub_modalidad, -1)
                 AND nvl(cod_oficina, -1) = nvl(f.cod_oficina, -1)
                 AND cod_moneda = m.cod_moneda
                 AND nvl(nro_cuenta, 'x') = nvl(f.nro_cuenta, 'x')
                 AND nvl(cod_persona, 'x') = nvl(f.cod_persona, 'x')
                 AND cod_tasa = f.cod_tasa
                 AND fec_vigencia = f.fec_vigencia;
            End if;
          End if;
        End loop; -- Fin loop de cursor de tasas fijas
        --------- PROCESO TASAS VARIABLES  ----------
        --- Seleccionar los registros en la moneda Base
        For v in c_tas_variables loop
          --- Verificar si ya existe con la moneda,
          --- si existe actualizar el valor si no insertar
          Begin
            Select no_actualizable, 1
              into v_no_actualizable, v_existe
              from ge_tas_rangos
             WHERE nvl(cod_modulo, -1) = nvl(v.cod_modulo, -1)
               AND nvl(cod_modalidad, -1) = nvl(v.cod_modalidad, -1)
               AND nvl(cod_sub_modalidad, -1) =
                   nvl(v.cod_sub_modalidad, -1)
               AND nvl(cod_oficina, -1) = nvl(v.cod_oficina, -1)
               AND cod_moneda = m.cod_moneda
               AND nvl(nro_cuenta, 'x') = nvl(v.nro_cuenta, 'x')
               AND cod_tasa = v.cod_tasa
               AND nvl(val_hasta, 0) = NVL(v.val_hasta, 0)
               AND fec_vigencia = v.fec_vigencia;
          Exception
            when no_data_found then
              v_existe          := 0;
              v_no_actualizable := 'N';
            when others then
              raise_application_error(-20000,
                                      'ERROR al buscar GE_TAS_RANGOS :  ' ||
                                      SQLERRM);
          End;
          --
          -- Verificar el tipo de aplicacion para no convertir los valores maximo y minimo
          -- que no corresponden a valor si no a cantidad o portentajes.
          /*If  reg.aplicar not in('CT','CE','CC','PL')
          and nvl(v.val_hasta,0) <> 0 then
             v_val_hasta := PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,m.cod_moneda,v.val_hasta);
          else
             v_val_hasta := v.val_hasta;
          End if;         */
          v_val_hasta := v.val_hasta;
          ------
          If v_existe = 0 then
            --Insertar
            Insert into ge_tas_rangos
              (Cod_Tasa,
               Fec_vigencia,
               cod_oficina,
               Cod_moneda,
               Cod_modulo,
               Cod_modalidad,
               Nro_cuenta,
               Val_hasta,
               Val_tasa,
               Cod_sub_modalidad)
            Values
              (reg.cod_tasa,
               v.fec_vigencia,
               v.cod_oficina,
               m.cod_moneda,
               v.cod_modulo,
               v.cod_modalidad,
               v.Nro_cuenta,
               v_val_hasta,
               decode(v.val_tasa,
                      null,
                      null,
                      0,
                      0,
                      PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                  m.cod_moneda,
                                                  v.val_tasa)),
               v.cod_sub_modalidad);
          else
            If nvl(v_no_actualizable, 'N') = 'N' then
              Update ge_tas_rangos
                 set val_tasa = decode(v.val_tasa,
                                       null,
                                       null,
                                       0,
                                       0,
                                       PAG_GEN.FU_CON_MON_A_MONEDA(reg.cod_mon_base,
                                                                   m.cod_moneda,
                                                                   v.val_tasa))
               WHERE nvl(cod_modulo, -1) = nvl(v.cod_modulo, -1)
                 AND nvl(cod_modalidad, -1) = nvl(v.cod_modalidad, -1)
                 AND nvl(cod_sub_modalidad, -1) =
                     nvl(v.cod_sub_modalidad, -1)
                 AND nvl(cod_oficina, -1) = nvl(v.cod_oficina, -1)
                 AND cod_moneda = m.cod_moneda
                 AND nvl(nro_cuenta, 'x') = nvl(v.nro_cuenta, 'x')
                 AND cod_tasa = v.cod_tasa
                 AND nvl(val_hasta, 0) = NVL(v.val_hasta, 0)
                 AND fec_vigencia = v.fec_vigencia;
            End if;
          End if;
        End loop; -- Fin loop de cursor de tasas Variables
      End loop; -- Fin loop de cursor de Monedas
    End;
  End loop; -- Fin loop de cursor de Tasas

EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,
                            'ERROR. en Proceso de Generacion de Tasas por Monedas ' ||
                            SQLERRM);
END;
/

