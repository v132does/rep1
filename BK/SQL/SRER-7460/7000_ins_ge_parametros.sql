BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END; 
/

insert into ge_parametros (PARAMETRO,DESCRIPCION,TAB_RELACION,OBSERVACION,MODIFICABLE) VALUES 
('MAD_AHO_PLAZO','CODIGO DE NUEVAS MODALIDADES','GE_PAR_DINAMICOS','Se utiliza en proceso PAS_CRI.pr_crc_gen_pasivas para incluir operaciones de nuevas modalidades','S');


insert into ge_par_dinamicos (PARAMETRO,VAL_PARAMETRO) values ('MAD_AHO_PLAZO',',37,');

COMMIT;
/