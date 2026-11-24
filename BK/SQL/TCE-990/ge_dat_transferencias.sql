ALTER TABLE it.ge_dat_transferencias
      ADD (metadata clob
          CONSTRAINT chk_dat_transferencias_json CHECK (metadata is json));
