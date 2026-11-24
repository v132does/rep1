create or replace force view it.gv_gru_tra_cob_car_atm as
select cod_gru_transaccion,
        b.abreviatura tipo,
        b.significado descripcion,
        pae_uti.FU_OBT_VALOR(val_maximo,1,';') cod_tra_bancard,
        to_number(pae_uti.FU_OBT_VALOR(val_maximo,2,';')) cod_tra_cargo,
        pae_uti.FU_OBT_VALOR(val_maximo,3,';') par_dinamico,
        pae_uti.FU_OBT_VALOR(val_maximo,4,';') ind_atm_propio
   from ge_mov_sin_costo a,
         ( select to_number(val_minimo) gru_transaccion,
                  abreviatura,
                  val_maximo,
                  significado
             from ba_cod_referencias
            where dominio = 'GRU_TRA_COB_CAR_ATM' ) b
   where a.cod_gru_transaccion = b.gru_transaccion
order by 1;

